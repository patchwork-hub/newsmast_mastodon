# frozen_string_literal: true

module NewsmastMastodon
  module Overrides
    module AccountSearchServiceExtension
      def call(query, account = nil, options = {})
        @local_only = options[:local_only] || false
        results = super

        # Post-filter for exact_match and elasticsearch paths
        if @local_only
          results.select(&:local?)
        else
          results
        end
      end

      private

      # When local_only is true, skip ResolveAccountService (which fetches remote/fediverse accounts)
      # and only look up local accounts by username.
      def exact_match
        return super unless @local_only

        return unless offset.zero? && username_complete?
        return @exact_match if defined?(@exact_match)

        match = if domain_is_local? || query_domain.nil?
                  Account.find_local(query_username)
        end

        match = nil if !match.nil? && !account.nil? && options[:following] && !account.following?(match)

        @exact_match = match
      end

      def advanced_search_results
        return super unless @local_only

        tsquery = Account.send(:generate_query_for_search, terms_for_query)

        if options[:following]
          sql = local_only_sql(Account::Search::ADVANCED_SEARCH_WITH_FOLLOWING)
          Account.find_by_sql([ sql, { id: account.id, limit: limit_for_non_exact_results, offset: offset, tsquery: tsquery } ]).tap do |records|
            ActiveRecord::Associations::Preloader.new(records: records, associations: [ :account_stat, { user: :role } ]).call
          end
        else
          sql = local_only_sql(Account::Search::ADVANCED_SEARCH_WITHOUT_FOLLOWING)
          Account.find_by_sql([ sql, { id: account.id, limit: limit_for_non_exact_results, offset: offset, tsquery: tsquery } ]).tap do |records|
            ActiveRecord::Associations::Preloader.new(records: records, associations: [ :account_stat, { user: :role } ]).call
          end
        end
      end

      def simple_search_results
        return super unless @local_only

        tsquery = Account.send(:generate_query_for_search, terms_for_query)
        sql = local_only_sql(Account::Search::BASIC_SEARCH_SQL)

        Account.find_by_sql([ sql, { limit: limit_for_non_exact_results, offset: offset, tsquery: tsquery } ]).tap do |records|
          ActiveRecord::Associations::Preloader.new(records: records, associations: [ :account_stat, { user: :role } ]).call
        end
      end

      def from_elasticsearch
        results = super
        return results unless @local_only && results

        results.select(&:local?)
      end

      def local_only_sql(sql_template)
        modified = sql_template.gsub(
          "(accounts.domain IS NOT NULL OR (users.approved = TRUE AND users.confirmed_at IS NOT NULL))",
          "accounts.domain IS NULL AND users.approved = TRUE AND users.confirmed_at IS NOT NULL"
        )

        # For the ADVANCED_SEARCH_WITH_FOLLOWING query which doesn't have the domain IS NOT NULL clause,
        # add domain IS NULL filter after suspended_at check
        unless modified.include?("accounts.domain IS NULL")
          modified = modified.gsub(
            "AND accounts.suspended_at IS NULL",
            "AND accounts.domain IS NULL AND accounts.suspended_at IS NULL"
          )
        end

        modified
      end
    end
  end
end
