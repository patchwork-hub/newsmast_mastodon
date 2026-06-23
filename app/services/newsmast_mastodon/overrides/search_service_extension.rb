# frozen_string_literal: true

module NewsmastMastodon
  module Overrides
    module SearchServiceExtension
      private

      def perform_accounts_search!
        AccountSearchService.new.call(
          @query,
          @account,
          limit: @limit,
          resolve: @resolve,
          offset: @offset,
          use_searchable_text: true,
          following: @following,
          start_with_hashtag: @query.start_with?("#"),
          query_fasp: @options[:query_fasp],
          local_only: @options[:local_only]
        )
      end
    end
  end
end
