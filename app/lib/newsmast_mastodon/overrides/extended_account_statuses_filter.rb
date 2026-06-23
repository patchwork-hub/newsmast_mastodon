# frozen_string_literal: true

# Namespace update: Posts::CommunityAdmin → NewsmastMastodon::CommunityAdmin
module NewsmastMastodon
  module Overrides
    module ExtendedAccountStatusesFilter
      include Redisable
      include PatchworkHelper

      KEYS = %i[
        pinned
        tagged
        only_media
        exclude_replies
        exclude_reblogs
        only_reblogs
        exclude_original_statuses
        exclude_direct_statuses
      ].freeze

      def results
        scope = no_boost_channel? ? custom_scope : initial_scope

        scope.merge!(pinned_scope)     if pinned?
        scope.merge!(only_media_scope) if only_media?
        scope.merge!(no_replies_scope) if exclude_replies?
        scope.merge!(no_reblogs_scope) if exclude_reblogs?
        scope.merge!(no_original_statuses_scope) if exclude_original_statuses?
        scope.merge!(hashtag_scope) if tagged?
        scope.merge!(only_rebogs_scope) if only_reblogs?
        scope.merge!(no_direct_statuses_scope) if exclude_direct_statuses?

        scope
      end

      private

      def only_rebogs_scope
        Status.fetch_reblogs
      end

      def no_original_statuses_scope
        Status.without_original_statuses
      end

      def no_direct_statuses_scope
        Status.without_direct_statuses
      end

      def only_reblogs?
        truthy_param?(:only_reblogs)
      end

      def exclude_original_statuses?
        truthy_param?(:exclude_original_statuses)
      end

      def exclude_direct_statuses?
        truthy_param?(:exclude_direct_statuses)
      end

      def no_boost_channel?
        begin
          return false unless patchwork_community_admin_exist?

          community_admin = NewsmastMastodon::CommunityAdmin
                              .includes(:community)
                              .find_by(account_id: @account.id, is_boost_bot: true)
        rescue StandardError
          return false
        end

        return false unless community_admin&.community&.no_boost_channel == true

        true
      end

      # for custom timelines
      def custom_scope
        status_ids = redis.zrange(FeedManager.instance.key(:custom, @account.id), 0, -1)
        Status.where(id: status_ids).joins(:account).merge(Account.without_suspended.without_silenced)
      end
    end
  end
end
