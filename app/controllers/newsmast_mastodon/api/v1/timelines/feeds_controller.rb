module NewsmastMastodon::Api::V1::Timelines
  class FeedsController < ::Api::V1::Timelines::BaseController
    before_action -> { authorize_if_got_token! :read, :'read:statuses' }

    PERMITTED_PARAMS = %i[local remote limit only_media].freeze

    def show
      @statuses = []
      username = params[:username]
      return render json: { error: "Username is required" }, status: :bad_request unless username.present?

      account = Account.find_by(username: username)
      return render json: { error: "Account not found" }, status: :not_found unless account.present?

      unless Object.const_defined?("ContentFilters::CommunityAdmin") && ContentFilters::CommunityAdmin.exists?(
          is_boost_bot: true,
          account_id: account.id,
          account_status: ContentFilters::CommunityAdmin.account_statuses[:active])
          return render json: { error: "Account is not a community admin" }, status: :not_found
      end

      cache_if_unauthenticated!
      @statuses = load_statuses
      render json: @statuses, each_serializer: REST::StatusSerializer, relationships: StatusRelationshipsPresenter.new(@statuses, current_user&.account_id)
    end

    private

    def load_statuses
      preloaded_custom_statuses_page
    end

    def preloaded_custom_statuses_page
      preload_collection(custom_statuses, Status)
    end

    def custom_statuses
      custom_feed.get(
        limit_param(DEFAULT_STATUSES_LIMIT),
        params[:max_id],
        params[:since_id],
        params[:min_id],
      )
    end

    def custom_feed
      NewsmastMastodon::CustomFeed.new(
        Account.find_by(username: params[:username], domain: nil),
        local: truthy_param?(:local),
        remote: truthy_param?(:remote),
        only_media: truthy_param?(:only_media)
      )
    end

    def next_path
      custom_feeds_url next_path_params
    end

    def prev_path
      custom_feeds_url prev_path_params
    end
  end
end
