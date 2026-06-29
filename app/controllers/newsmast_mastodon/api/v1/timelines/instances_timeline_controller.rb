# frozen_string_literal: true

module NewsmastMastodon::Api::V1::Timelines
  # GET /api/v1/timelines/instances_timeline
  #
  # Returns a paginated timeline composed of:
  # - home timeline statuses (always included)
  # - relay timeline statuses for selected domains
  #
  # Domain parameter supports:
  # - none: uses all configured and enabled relay domains
  # - single: ?domain=mastodon.social
  # - multiple: ?domain=mastodon.social,mastodon.beer
  #             ?domain[]=mastodon.social&domain[]=mastodon.beer
  class InstancesTimelineController < ::Api::V1::Timelines::BaseController
    before_action -> { doorkeeper_authorize! :read, :'read:statuses' }
    before_action :require_user!
    before_action :validate_requested_domains!

    PERMITTED_PARAMS = %i(domain limit only_media max_id since_id min_id).freeze

    def show
      with_read_replica do
        @statuses = load_statuses
        @relationships = StatusRelationshipsPresenter.new(@statuses, current_user&.account_id)
      end

      render json: @statuses,
             each_serializer: REST::StatusSerializer,
             relationships: @relationships
    end

    private

    def load_statuses
      preload_collection(instances_timeline_statuses, Status)
    end

    def instances_timeline_statuses
      limit = limit_param(DEFAULT_STATUSES_LIMIT)

      home_statuses = HomeFeed.new(current_account).get(
        expanded_limit(limit),
        params[:max_id],
        params[:since_id],
        params[:min_id]
      )

      relay_statuses = selected_domains.flat_map do |domain|
        NewsmastMastodon::RelayFeed.new(
          domain,
          current_account,
          only_media: truthy_param?(:only_media)
        ).get(
          expanded_limit(limit),
          params[:max_id],
          params[:since_id],
          params[:min_id]
        )
      end

      status_ids = (home_statuses.map(&:id) + relay_statuses.map(&:id)).uniq.sort.reverse.first(limit)
      return [] if status_ids.empty?

      scope = Status.where(id: status_ids).joins(:account).merge(Account.without_suspended.without_silenced)
      scope = scope.joins(:media_attachments).group(:id) if truthy_param?(:only_media)

      records = scope.index_by(&:id)
      status_ids.filter_map { |id| records[id] }
    end

    def requested_domains
      @requested_domains ||= begin
        raw = params[:domain]

        Array(raw)
          .flat_map { |value| value.to_s.split(',') }
          .map { |value| value.strip.downcase }
          .reject(&:blank?)
          .uniq
      end
    end

    def configured_domains
      @configured_domains ||= NewsmastMastodon::CustomRelayConfig.domains
    end

    def enabled_domains
      @enabled_domains ||= begin
        inbox_urls = configured_domains.map { |domain| NewsmastMastodon::CustomRelayConfig.inbox_url_for(domain) }
        Relay.enabled.where(inbox_url: inbox_urls).pluck(:inbox_url).filter_map do |url|
          NewsmastMastodon::CustomRelayConfig.domain_from_inbox_url(url)
        end
      end
    end

    def selected_domains
      return enabled_domains if requested_domains.empty?

      requested_domains & enabled_domains
    end

    def validate_requested_domains!
      unknown = requested_domains - configured_domains
      return if unknown.empty?

      render json: { error: "Unknown relay domains: #{unknown.join(', ')}" }, status: :bad_request
    end

    def expanded_limit(limit)
      # Pull extra records before dedup/merge so final page can still fill.
      [limit * 3, 120].min
    end

    def next_path
      api_v1_timelines_instances_timeline_url(next_path_params.merge(domain: params[:domain]))
    end

    def prev_path
      api_v1_timelines_instances_timeline_url(prev_path_params.merge(domain: params[:domain]))
    end
  end
end
