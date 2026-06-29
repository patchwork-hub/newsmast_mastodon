# frozen_string_literal: true

# Extends FeedManager with custom timeline support.
module NewsmastMastodon
  module Concerns
    module FeedManagerConcern
      extend ActiveSupport::Concern

      included do
        # Add custom timeline methods to FeedManager
      end

      # Push a status to custom timeline.
      # @param [Account] account
      # @param [Status] status
      # @param [Boolean] update
      # @return [Boolean]
      def push_to_custom(account, status, update: false)
        return false unless account.user&.signed_in_recently?
        return false if filter_from_custom?(status, account)
        return false unless add_to_feed(:custom, account.id, status, aggregate_reblogs: account.user&.aggregates_reblogs?)

        trim(:custom, account.id)
        if push_update_required?("timeline:custom:#{account.id}")
          PushUpdateWorker.perform_async(account.id, status.id, "timeline:custom:#{account.id}", { "update" => update })
        end
        true
      end

      # Remove a status from custom timeline.
      # @param [Account] account
      # @param [Status] status
      # @param [Boolean] update
      # @return [Boolean]
      def unpush_from_custom(account, status, update: false)
        return false unless NewsmastMastodon::CommunityAdmin.table_exists?
        return false unless NewsmastMastodon::CommunityAdmin.exists?(
          is_boost_bot: true,
          account_id: account.id,
          account_status: NewsmastMastodon::CommunityAdmin.account_statuses[:active]
        )
        return false unless remove_from_feed(:custom, account.id, status, aggregate_reblogs: account.user&.aggregates_reblogs?)

        redis.publish("timeline:custom:#{account.id}", Oj.dump(event: :delete, payload: status.id.to_s)) unless update
        true
      end

      # Populate custom timeline from scratch.
      # @param [Account] account
      # @return [void]
      def populate_custom(account)
        limit        = FeedManager::MAX_ITEMS / 2
        aggregate    = account.user&.aggregates_reblogs?
        timeline_key = key(:custom, account.id)

        statuses = Status
                   .where(account: custom_timeline_accounts_for(account))
                   .list_eligible_visibility
                   .includes(:preloadable_poll, :media_attachments, :account, reblog: :account)
                   .limit(limit)
                   .order(id: :desc)

        crutches = build_crutches(account.id, statuses)

        statuses.each do |status|
          next if filter_from_custom?(status, account, crutches)

          add_to_feed(:custom, account.id, status, aggregate_reblogs: aggregate)
        end

        trim(:custom, account.id)
      end

      # Merge an account's statuses into custom timeline.
      # @param [Account] from_account
      # @param [Account] into_account
      # @return [void]
      def merge_into_custom(from_account, into_account)
        return unless into_account.user&.signed_in_recently?

        timeline_key = key(:custom, into_account.id)
        aggregate    = into_account.user&.aggregates_reblogs?
        query        = from_account.statuses.list_eligible_visibility
                                   .includes(:preloadable_poll, :media_attachments, reblog: :account)
                                   .limit(FeedManager::MAX_ITEMS / 4)

        if redis.zcard(timeline_key) >= FeedManager::MAX_ITEMS / 4
          oldest_score = redis.zrange(timeline_key, 0, 0, with_scores: true).first.last.to_i
          query = query.where("id > ?", oldest_score)
        end

        statuses = query.to_a
        crutches = build_crutches(into_account.id, statuses)

        statuses.each do |status|
          next if filter_from_custom?(status, into_account, crutches)

          add_to_feed(:custom, into_account.id, status, aggregate_reblogs: aggregate)
        end

        trim(:custom, into_account.id)
      end

      # Remove an account's statuses from custom timeline.
      # @param [Account] from_account
      # @param [Account] into_account
      # @return [void]
      def unmerge_from_custom(from_account, into_account)
        timeline_key        = key(:custom, into_account.id)
        timeline_status_ids = redis.zrange(timeline_key, 0, -1)

        from_account.statuses.select(:id, :reblog_of_id)
                    .where(id: timeline_status_ids)
                    .reorder(nil)
                    .find_each do |status|
          remove_from_feed(:custom, into_account.id, status, aggregate_reblogs: into_account.user&.aggregates_reblogs?)
        end
      end

      # Filter for custom timeline.
      # @param [Status] status
      # @param [Account] account
      # @param [Hash] crutches
      # @return [Boolean]
      def filter_from_custom?(status, account, crutches = nil)
        crutches ||= build_crutches(account.id, [ status ])

        base_filter = filter_from_home(status, account.id, crutches, :custom)
        return true if base_filter == :filter

        false
      end

      private

      # Define which accounts should appear in the custom timeline.
      # @param [Account] account
      # @return [ActiveRecord::Relation<Account>]
      def custom_timeline_accounts_for(account)
        # Placeholder implementation — customise per deployment.
        account.following
      end
    end
  end
end
