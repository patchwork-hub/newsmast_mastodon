# frozen_string_literal: true

module NewsmastMastodon
  module Overrides
    module NotificationV1ExtendedController
      DEFAULT_NOTIFICATIONS_LIMIT = 40

      def load_notifications
        notifications = browserable_account_notifications.includes(from_account: [ :account_stat, :user ]).to_a_paginated_by_id(
          limit_param(DEFAULT_NOTIFICATIONS_LIMIT),
          params_slice(:max_id, :since_id, :min_id)
        )

        notifications = filter_private_mentions(notifications) if truthy_param?(:exclude_private_mentions)

        Notification.preload_cache_collection_target_statuses(notifications) do |target_statuses|
          preload_collection(target_statuses, Status)
        end
      end

      def filter_private_mentions(notifications)
        notifications.reject do |notification|
          notification.type == :mention &&
            notification.target_status&.visibility == "direct"
        end
      end

      def browserable_params
        params.permit(:account_id, :include_filtered, :exclude_private_mentions, types: [], exclude_types: [])
      end

      def pagination_params(core_params)
        params.slice(:limit, :account_id, :types, :exclude_types, :include_filtered, :exclude_private_mentions).permit(:limit, :account_id, :include_filtered, :exclude_private_mentions, types: [], exclude_types: []).merge(core_params)
      end
    end
  end
end
