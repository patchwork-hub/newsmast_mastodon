# frozen_string_literal: true


module NewsmastMastodon
  module Overrides
    module ReblogServiceExtension
      def call(account, reblogged_status, options = {})
        reblogged_status = reblogged_status.reblog if reblogged_status.reblog?

        authorize_with account, reblogged_status, :reblog?

        reblog = account.statuses.find_by(reblog: reblogged_status)

        return reblog unless reblog.nil?

        visibility = if reblogged_status.hidden?
                       reblogged_status.visibility
        else
                       options[:visibility] || account.user&.setting_default_privacy
        end

        reblog = account.statuses.create!(reblog: reblogged_status, text: "", visibility: visibility, rate_limit: options[:with_rate_limit])

        Trends.register!(reblog)
        DistributionWorker.perform_async(reblog.id)
        ActivityPub::DistributionWorker.perform_async(reblog.id) unless reblogged_status.local_only?

        create_notification(reblog)
        increment_statistics

        reblog
      end
    end
  end
end
