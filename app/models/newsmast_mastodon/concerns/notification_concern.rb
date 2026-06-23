# frozen_string_literal: true

module NewsmastMastodon
  module Concerns
    module NotificationConcern
      extend ActiveSupport::Concern

      class_methods do
        def browserable(types: [], exclude_types: [], from_account_id: nil, include_filtered: false, only_direct_mentions: false)
          # Call the original method with standard parameters
          scope = super(
            types: types,
            exclude_types: exclude_types,
            from_account_id: from_account_id,
            include_filtered: include_filtered
          )

          # Add custom filtering for direct mentions.
          if only_direct_mentions && (types.empty? || types.map(&:to_sym).include?(:mention))
            scope = scope.merge(direct_mentions_only)
          end

          scope
        end

        # Filter mentions by direct visibility.
        def direct_mentions_only
          left_joins(mention: :status)
            .where(
              "(notifications.type != ? OR statuses.visibility = ?)",
              "mention",
              Status.visibilities[:direct]
            )
        end
      end
    end
  end
end
