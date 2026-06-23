# frozen_string_literal: true

# Prepended/included into FanOutOnWriteService to fan out posts into the custom timeline.
module NewsmastMastodon
  module Concerns
    module FanOutOnWriteConcern
      extend ActiveSupport::Concern

      included do
        alias_method :original_call, :call

        def call(status, options = {})
          @options = options
          original_call(status, options)
          fan_out_to_custom_timeline!
        end
      end

      private

      def fan_out_to_custom_timeline!
        # Determine which accounts should receive this status in their custom timeline.
        accounts        = @options[:admin_accounts]
        target_accounts = Account.where(id: accounts)

        target_accounts.select(:id).reorder(nil).find_in_batches do |batch|
          NewsmastMastodon::CustomFeedInsertWorker.push_bulk(batch) do |account|
            [ @status.id, account.id, { "update" => update? } ]
          end
        end
      end
    end
  end
end
