# frozen_string_literal: true

module NewsmastMastodon
  module Overrides
    module PublicExtendedTimeline
      PERMITTED_PARAMS = %i[local remote limit only_media with_reblogs with_replies grouped_admin_statuses].freeze

      def public_feed
        PublicFeed.new(
          current_account,
          local: truthy_param?(:local),
          remote: truthy_param?(:remote),
          only_media: truthy_param?(:only_media),
          with_reblogs: truthy_param?(:with_reblogs),
          with_replies: truthy_param?(:with_replies),
          grouped_admin_statuses: truthy_param?(:grouped_admin_statuses)
        )
      end
    end
  end
end
