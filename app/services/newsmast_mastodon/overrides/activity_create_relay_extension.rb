# frozen_string_literal: true

module NewsmastMastodon
  module Overrides
    # Prepended into ActivityPub::Activity::Create to intercept statuses
    # received via a configured custom relay and add them to a per-domain
    # Redis sorted set (feed:relay:<sanitized_domain>).
    module ActivityCreateRelayExtension
      include Redisable

      RELAY_FEED_MAX_ITEMS = 800

      private

      # Override create_status to hook in after the parent creates the Status
      # record, while still having access to @options[:relayed_through_actor].
      def create_status
        @status = super

        author_domain = @status.account&.domain
        log_relay_debug("Before: status_id=#{@status.id} domain=#{author_domain}")
        if @status.present?
          # Normalize domains to avoid mismatches caused by case/whitespace
          author_domain_norm = author_domain.to_s.downcase.strip
          configured_domains_norm = custom_relay_domains.map { |d| d.to_s.downcase.strip }

          unless configured_domains_norm.any?
            log_relay_debug("CUSTOM_RELAY_DOMAINS appears empty or not configured: #{custom_relay_domains.inspect}")
          end

          if author_domain_norm.present? && configured_domains_norm.include?(author_domain_norm)
            log_relay_debug("Added relay feed insert: status_id=#{@status.id} domain=#{author_domain_norm}")
            add_to_relay_feed(author_domain_norm)
          else
            log_relay_debug("Author domain not in configured custom relay domains: author=#{author_domain_norm} configured=#{configured_domains_norm.inspect}")
          end

          if relay_status?
            relay_account = @options[:relayed_through_actor]
            relay_domain  = NewsmastMastodon::CustomRelayConfig.domain_from_inbox_url(relay_account.inbox_url)
            add_to_relay_feed(relay_domain)
          end
        end

        @status
      end

      # Returns true only when the status was delivered through one of the
      # ENV-configured custom relay domains.
      def relay_status?
        unless @status.present?
          log_relay_debug("Skipping relay feed insert: no status created")
          return false
        end

        unless @options[:relayed_through_actor].present?
          log_relay_debug("Skipping relay feed insert: status_id=#{@status.id} was not delivered through a relay @options[:relayed_through_actor]=#{@options[:relayed_through_actor].inspect}")
          return false
        end

        relay_account = @options[:relayed_through_actor]
        relay = Relay.find_by(inbox_url: relay_account.inbox_url)
        unless relay&.enabled?
          log_relay_debug("Skipping relay feed insert: status_id=#{@status.id} relay_inbox=#{relay_account.inbox_url} is not enabled")
          return false
        end

        domain = NewsmastMastodon::CustomRelayConfig.domain_from_inbox_url(relay.inbox_url)
        unless domain.present? && custom_relay_domains.include?(domain)
          log_relay_debug("Skipping relay feed insert: status_id=#{@status.id} relay_domain=#{domain.inspect} is not in CUSTOM_RELAY_DOMAINS")
          return false
        end

        true
      end

      def add_to_relay_feed(domain)
        return unless domain.present?

        key           = NewsmastMastodon::RelayFeed.timeline_key(domain)

        with_redis do |redis|
          inserted = redis.zadd(key, @status.id, @status.id)
          # Trim oldest entries beyond the cap (rank 0 = oldest)
          redis.zremrangebyrank(key, 0, -(RELAY_FEED_MAX_ITEMS + 1))
          # 30-day TTL as a safety net for stale feeds
          redis.expire(key, 30.days.to_i)

          log_relay_debug(
            "Relay feed insert: status_id=#{@status.id} domain=#{domain} key=#{key} " \
            "zadd_result=#{inserted.inspect} zcard=#{redis.zcard(key)}"
          )
        end
      end

      def custom_relay_domains
        NewsmastMastodon::CustomRelayConfig.domains
      end

      def log_relay_debug(message)
        Rails.logger.info("[newsmast_mastodon] #{message}")
      end
    end
  end
end
