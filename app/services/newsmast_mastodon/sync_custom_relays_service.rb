# frozen_string_literal: true

module NewsmastMastodon
  # Synchronises the Relay records in the database against the domains listed
  # in the CUSTOM_RELAY_DOMAINS environment variable.
  #
  # - Domains present in ENV but absent from DB  → create Relay + enable!
  # - Domains present in DB but absent from ENV  → disable! + destroy Relay
  #                                                + delete Redis timeline
  # - Domains in both with state == accepted     → no-op (idempotent)
  #
  # All enable!/disable! calls are guarded against their current state to
  # avoid sending duplicate Follow/Undo ActivityPub activities.
  class SyncCustomRelaysService
    include Redisable

    def call
      env_domains     = NewsmastMastodon::CustomRelayConfig.domains
      managed_relays  = Relay.where(inbox_url: env_domains.map { |d| NewsmastMastodon::CustomRelayConfig.inbox_url_for(d) })
      managed_urls    = managed_relays.pluck(:inbox_url)
      env_urls        = env_domains.map { |d| NewsmastMastodon::CustomRelayConfig.inbox_url_for(d) }

      {
        env_domains: env_domains,
        env_urls: env_urls,
        managed_urls: managed_urls,
        added: add_missing_relays(env_urls - managed_urls),
        removed: remove_stale_relays(managed_urls - env_urls)
      }
    end

    private

    def add_missing_relays(inbox_urls)
      added = 0
      inbox_urls.each do |url|
        relay = Relay.find_or_initialize_by(inbox_url: url)
        next if relay.accepted? || relay.pending?

        relay.save! if relay.new_record?
        relay.enable!
        added += 1
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn("[NewsmastMastodon] SyncCustomRelaysService: could not add relay #{url}: #{e.message}")
      end
      added
    end

    def remove_stale_relays(inbox_urls)
      removed = 0
      inbox_urls.each do |url|
        relay = Relay.find_by(inbox_url: url)
        next unless relay

        domain = NewsmastMastodon::CustomRelayConfig.domain_from_inbox_url(url)
        relay.disable! if relay.accepted?
        relay.destroy!
        delete_relay_timeline(domain) if domain.present?
        removed += 1
      rescue StandardError => e
        Rails.logger.warn("[NewsmastMastodon] SyncCustomRelaysService: could not remove relay #{url}: #{e.message}")
      end
      removed
    end

    def delete_relay_timeline(domain)
      key = NewsmastMastodon::RelayFeed.timeline_key(domain)
      with_redis { |redis| redis.del(key) }
    end
  end
end
