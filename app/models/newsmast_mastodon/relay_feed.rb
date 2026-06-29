# frozen_string_literal: true

module NewsmastMastodon
  # Feed class for a single relay domain timeline.
  #
  # Reads status IDs from the Redis sorted set at feed:relay:<sanitized_domain>
  # and returns the corresponding Status records with standard pagination.
  class RelayFeed
    include Redisable

    # Returns the Redis key for the given domain's relay timeline.
    #
    # @param domain [String] e.g. "mastodon.social"
    # @return [String] e.g. "feed:relay:mastodon-social"
    def self.timeline_key(domain)
      sanitized = NewsmastMastodon::CustomRelayConfig.sanitize_domain(domain)
      "feed:relay:#{sanitized}"
    end

    # @param domain  [String]  The relay domain (e.g. "mastodon.social")
    # @param account [Account] Optional – used for per-account filters
    # @param options [Hash]
    # @option options [Boolean] :only_media
    def initialize(domain, account = nil, options = {})
      @domain  = domain
      @account = account
      @options = options
    end

    # @param limit    [Integer]
    # @param max_id   [Integer, nil]
    # @param since_id [Integer, nil]
    # @param min_id   [Integer, nil]
    # @return [Array<Status>]
    def get(limit, max_id = nil, since_id = nil, min_id = nil)
      scope = relay_scope
      scope.merge!(media_only_scope) if media_only?
      scope.to_a_paginated_by_id(limit, max_id: max_id, since_id: since_id, min_id: min_id)
    end

    private

    attr_reader :domain, :account, :options

    def media_only?
      options[:only_media]
    end

    def relay_scope
      status_ids = redis.zrange(self.class.timeline_key(domain), 0, -1)
      Status.where(id: status_ids)
            .joins(:account)
            .merge(Account.without_suspended.without_silenced)
    end

    def media_only_scope
      Status.joins(:media_attachments).group(:id)
    end
  end
end
