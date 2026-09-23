# frozen_string_literal: true

# Timeline fetch supports optional filters for direct visibility, followed tags,
# replies, and grouped admin exclusions.
module NewsmastMastodon
  module Concerns
    module FeedConcern
      extend ActiveSupport::Concern
      include Redisable

      def get(limit, max_id = nil, since_id = nil, min_id = nil, account = nil,
              exclude_direct_statuses = false, exclude_followed_tags = false,
              exclude_replies = false, grouped_admin_statuses = false)
        @account = account if account.present? && exclude_followed_tags

        limit    = limit.to_i
        max_id   = max_id.to_i if max_id.present?
        since_id = since_id.to_i if since_id.present?
        min_id   = min_id.to_i if min_id.present?

        from_redis(
          limit, max_id, since_id, min_id,
          exclude_direct_statuses, exclude_followed_tags, exclude_replies, grouped_admin_statuses
        )
      end

      def from_redis(limit, max_id, since_id, min_id,
                     exclude_direct_statuses = nil, exclude_followed_tags = nil,
                     exclude_replies = nil, grouped_admin_statuses = nil)
        max_id = "+inf" if max_id.blank?
        unhydrated =
          if min_id.blank?
            since_id = "-inf" if since_id.blank?
            redis.zrevrangebyscore(key, "(#{max_id}", "(#{since_id}", limit: [ 0, limit ], with_scores: true).map { |id| id.first.to_i }
          else
            redis.zrangebyscore(key, "(#{min_id}", "(#{max_id}", limit: [ 0, limit ], with_scores: true).map { |id| id.first.to_i }
          end

        filter_and_cache_statuses(unhydrated)

        # Exclude direct posts without dropping private visibility posts.
        @statuses = @statuses.where.not(visibility: %i[direct]) if exclude_direct_statuses

        if exclude_followed_tags
          followed_tag_ids = @account.followed_tags.pluck(:id)
          @statuses = @statuses.tagged_without(followed_tag_ids)
        end

        @statuses = @statuses.where(reply: false) if exclude_replies

        if grouped_admin_statuses
          return @statuses unless Status.column_names.include?("local_only")

          grouped_admin_account_ids = fetch_grouped_admin_account_ids
          if grouped_admin_account_ids.any?
            @statuses = @statuses.where.not(account_id: grouped_admin_account_ids, local_only: true, local: true)

            grouped_admin_reblogged_ids = Status
              .where(account_id: grouped_admin_account_ids, local_only: true, local: true)
              .where.not(reblog_of_id: nil)
              .select(:reblog_of_id)

            @statuses = @statuses.where.not(id: grouped_admin_reblogged_ids) if grouped_admin_reblogged_ids.any?
          end
        end

        @statuses
      end

      # Apply ban-list filtering before downstream timeline filters.
      def filter_and_cache_statuses(unhydrated)
        filter_service = NewsmastMastodon::FeedService.new
        banned_ids     = filter_service.excluded_status_ids
        @statuses      = Status.where(id: unhydrated)
        @statuses      = @statuses.where.not(id: banned_ids) if banned_ids.any?
        @statuses
      end

      def fetch_grouped_admin_account_ids
        Rails.cache.fetch("grouped_admin_account_ids", expires_in: 1.hour) do
          NewsmastMastodon::CommunityAdmin
            .includes(:community)
            .where(
              is_boost_bot: true,
              account_status: NewsmastMastodon::CommunityAdmin.account_statuses[:active],
              community: { channel_type: NewsmastMastodon::Community.channel_types[:channel_feed] }
            )
            .pluck(:account_id)
            .uniq
        end
      end
    end
  end
end
