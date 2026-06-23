# frozen_string_literal: true

require "set"

class CustomFeedsStatusRelationshipsPresenter
  attr_reader :reblogs_map, :favourites_map, :mutes_map, :pins_map,
              :bookmarks_map, :filters_map, :attributes_map

  def initialize(statuses, account_id = nil, **options)
    @original_statuses = statuses
    @original_account_id = account_id

    filtered_statuses = filter_boosted_statuses_inline(statuses)

    if account_id.nil?
      @preloaded_account_relations = {}
      @filters_map     = {}
      @reblogs_map     = {}
      @favourites_map  = {}
      @bookmarks_map   = {}
      @mutes_map       = {}
      @pins_map        = {}
      @attributes_map  = {}
    else
      @preloaded_account_relations = nil

      statuses = filtered_statuses.compact
      status_ids = statuses.flat_map { |s| [ s.id, s.reblog_of_id, s.proper.quote&.quoted_status_id ] }.uniq.compact
      conversation_ids = statuses.flat_map { |s| [ s.proper.conversation_id, s.proper.quote&.quoted_status&.conversation_id ] }.uniq.compact
      pinnable_status_ids = statuses.flat_map { |s| [ s.proper, s.proper.quote&.quoted_status ] }.compact.map { |s| s.id if s.account_id == account_id && %w[public unlisted private].include?(s.visibility) }.compact

      @filters_map     = build_filters_map(statuses.flat_map { |s| [ s, s.proper.quote&.quoted_status ] }.compact.uniq, account_id).merge(options[:filters_map] || {})

      if defined?(Status)
        @reblogs_map     = Status.reblogs_map(status_ids, account_id).merge(options[:reblogs_map] || {})
        @favourites_map  = Status.favourites_map(status_ids, account_id).merge(options[:favourites_map] || {})
        @bookmarks_map   = Status.bookmarks_map(status_ids, account_id).merge(options[:bookmarks_map] || {})
        @mutes_map       = Status.mutes_map(conversation_ids, account_id).merge(options[:mutes_map] || {})
        @pins_map        = Status.pins_map(pinnable_status_ids, account_id).merge(options[:pins_map] || {})
      else
        @reblogs_map     = options[:reblogs_map] || {}
        @favourites_map  = options[:favourites_map] || {}
        @bookmarks_map   = options[:bookmarks_map] || {}
        @mutes_map       = options[:mutes_map] || {}
        @pins_map        = options[:pins_map] || {}
      end
      @attributes_map  = options[:attributes_map] || {}
    end
  end

  def filters_map
    @filters_map || {}
  end

  def relationships
    self
  end

  def filtered
    self
  end

  def boosted?(status)
    status.respond_to?(:reblog_id) && !status.reblog_id.nil?
  end

  def get_original_status(boosted_status)
    if boosted_status.respond_to?(:reblog) && boosted_status.reblog
      boosted_status.reblog
    elsif boosted_status.respond_to?(:reblog_id) && boosted_status.reblog_id
      nil
    end
  end

  def filter_boosted_statuses_inline(statuses)
    filtered = []
    seen_original_ids = Set.new

    statuses.each do |status|
      if boosted?(status)
        original_status = get_original_status(status)
        if original_status && !seen_original_ids.include?(original_status.id)
          filtered << original_status
          seen_original_ids.add(original_status.id)
        end
      else
        filtered << status
      end
    end

    filtered
  end

  def relationship_data_for(status_id)
    return {} if @original_statuses.nil? || @original_statuses.empty? || @original_account_id.nil?

    filtered_statuses = filter_boosted_statuses_inline(@original_statuses)

    status = filtered_statuses.find { |s| s.id == status_id }
    return {} unless status

    {
      reblogged: reblogs_map[status.id] || false,
      favourited: favourites_map[status.id] || false,
      bookmarked: bookmarks_map[status.id] || false,
      muted: mutes_map[status.id] || false,
      pinned: pins_map[status.id] || false
    }
  end

  private

  def statuses_blank?
    @original_statuses.nil? || @original_statuses.empty?
  end

  def account_id_blank?
    @original_account_id.nil?
  end

  def preloaded_account_relations
    @preloaded_account_relations ||= begin
      if defined?(Account)
        accounts = @original_statuses.compact.flat_map { |s| [ s.account, s.proper.account, s.proper.quote&.quoted_account ] }.uniq.compact

        account_ids = accounts.pluck(:id)
        account_domains = accounts.pluck(:domain).uniq
        Account.find(@original_account_id).relations_map(account_ids, account_domains)
      else
        {}
      end
    end
  end

  def build_filters_map(statuses, current_account_id)
    if defined?(CustomFilter)
      active_filters = CustomFilter.cached_filters_for(current_account_id)

      @filters_map = statuses.each_with_object({}) do |status, h|
        filter_matches = CustomFilter.apply_cached_filters(active_filters, status)

        unless filter_matches.empty?
          h[status.id] = filter_matches
          h[status.reblog_of_id] = filter_matches if status.reblog?
        end
      end
    else
      @filters_map = {}
    end
  end
end
