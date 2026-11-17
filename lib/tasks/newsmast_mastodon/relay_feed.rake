# frozen_string_literal: true

# Backfill feed:relay:<domain> Redis sorted sets from statuses already stored
# in the database for each CUSTOM_RELAY_DOMAINS entry.
#
# Usage:
#   DRY_RUN=true  bundle exec rake newsmast_mastodon:relay_feed:backfill
#   DRY_RUN=false bundle exec rake newsmast_mastodon:relay_feed:backfill
#   DRY_RUN=false DOMAINS=mastodon.social bundle exec rake newsmast_mastodon:relay_feed:backfill
namespace :newsmast_mastodon do
  namespace :relay_feed do
    desc "Backfill relay feed Redis keys from existing statuses (DRY_RUN=true by default)"
    task backfill: :environment do
      dry_run  = ENV.fetch("DRY_RUN", "true") != "false"
      max      = NewsmastMastodon::Overrides::ActivityCreateRelayExtension::RELAY_FEED_MAX_ITEMS
      override = ENV.fetch("DOMAINS", "").split(",").map { |d| d.strip.downcase }.reject(&:blank?)
      domains  = override.presence || NewsmastMastodon::CustomRelayConfig.domains

      if domains.empty?
        puts "No domains configured. Set CUSTOM_RELAY_DOMAINS or DOMAINS."
        next
      end

      puts "Relay feed backfill (#{dry_run ? 'DRY RUN' : 'LIVE'}) for: #{domains.join(', ')}"
      redis = Object.new.extend(Redisable).redis

      domains.each do |domain|
        key        = NewsmastMastodon::RelayFeed.timeline_key(domain)
        status_ids = Status.where(account_id: Account.where(domain: domain).select(:id))
                           .where(reblog_of_id: nil)
                           .order(id: :desc)
                           .limit(max)
                           .pluck(:id)

        if status_ids.empty?
          puts "  #{domain}: no statuses found (key=#{key})"
          next
        end

        if dry_run
          puts "  #{domain}: would add #{status_ids.size} statuses to #{key}"
          next
        end

        redis.zadd(key, status_ids.map { |id| [ id, id ] })
        redis.zremrangebyrank(key, 0, -(max + 1))
        redis.expire(key, 30.days.to_i)
        puts "  #{domain}: added #{status_ids.size} statuses to #{key} (zcard=#{redis.zcard(key)})"
      end

      puts "Done."
    end
  end
end
