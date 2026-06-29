# frozen_string_literal: true

module NewsmastMastodon
  module Overrides
    module NotificationExtendedController
      def browserable_account_notifications
        current_account.notifications.without_suspended.browserable(
          types: Array(browserable_params[:types]),
          exclude_types: Array(browserable_params[:exclude_types]),
          include_filtered: truthy_param?(:include_filtered),
          only_direct_mentions: truthy_param?(:only_direct_mentions)
        )
      end

      def load_grouped_notifications
        return [] if @notifications.empty?

        MastodonOTELTracer.in_span("Api::V2::NotificationsController#load_grouped_notifications") do
          pagination_range = (@notifications.last.id)..@notifications.first.id

          # If the page is incomplete, we know we are on the last page
          if incomplete_page?
            if paginating_up?
              pagination_range = @notifications.last.id...(params[:max_id]&.to_i)
            else
              range_start = params[:since_id]&.to_i
              range_start += 1 unless range_start.nil?
              pagination_range = range_start..(@notifications.first.id)
            end
          end

          notifications = NotificationGroup.from_notifications(@notifications, pagination_range: pagination_range, grouped_types: params[:grouped_types])
          notifications = filter_private_mentions(notifications) if exclude_private_mentions?
          notifications
        end
      end

      def filter_private_mentions(notifications)
        notifications.reject do |notification|
          notification.target_status&.visibility == "direct"
        end
      end

      def exclude_private_mentions?
        truthy_param?(:exclude_private_mentions)
      end

      def browserable_params
        params.slice(:include_filtered, :types, :exclude_types, :grouped_types, :only_direct_mentions, :exclude_private_mentions).permit(:only_direct_mentions, :include_filtered, :exclude_private_mentions, types: [], exclude_types: [], grouped_types: [])
      end

      def pagination_params(core_params)
        params.slice(:limit, :include_filtered, :types, :exclude_types, :grouped_types, :only_direct_mentions, :exclude_private_mentions).permit(:limit, :only_direct_mentions, :include_filtered, :exclude_private_mentions, types: [], exclude_types: [], grouped_types: []).merge(core_params)
      end
    end
  end
end
