# frozen_string_literal: true

# Overrides Account::Search constants to include is_banned filtering.
module NewsmastMastodon
  module Concerns
    module AccountSearchConcern
      extend ActiveSupport::Concern

      included do
        BASIC_SEARCH_SQL = <<~SQL.squish
          SELECT
            accounts.*,
            #{Account::Search::BOOST} * ts_rank_cd(#{Account::Search::TEXT_SEARCH_RANKS}, to_tsquery('simple', :tsquery), 32) AS rank
          FROM accounts
          LEFT JOIN users ON accounts.id = users.account_id
          LEFT JOIN account_stats AS s ON accounts.id = s.account_id
          WHERE to_tsquery('simple', :tsquery) @@ #{Account::Search::TEXT_SEARCH_RANKS}
            AND accounts.suspended_at IS NULL
            AND accounts.moved_to_account_id IS NULL
            AND accounts.is_banned = FALSE
            AND (accounts.domain IS NOT NULL OR (users.approved = TRUE AND users.confirmed_at IS NOT NULL))
          ORDER BY rank DESC
          LIMIT :limit OFFSET :offset
        SQL

        ADVANCED_SEARCH_WITH_FOLLOWING = <<~SQL.squish
          WITH first_degree AS (
            SELECT target_account_id
            FROM follows
            WHERE account_id = :id
            UNION ALL
            SELECT :id
          )
          SELECT
            accounts.*,
            (count(f.id) + 1) * #{Account::Search::BOOST} * ts_rank_cd(#{Account::Search::TEXT_SEARCH_RANKS}, to_tsquery('simple', :tsquery), 32) AS rank
          FROM accounts
          LEFT OUTER JOIN follows AS f ON (accounts.id = f.account_id AND f.target_account_id = :id)
          LEFT JOIN account_stats AS s ON accounts.id = s.account_id
          WHERE accounts.id IN (SELECT * FROM first_degree)
            AND to_tsquery('simple', :tsquery) @@ #{Account::Search::TEXT_SEARCH_RANKS}
            AND accounts.suspended_at IS NULL
            AND accounts.moved_to_account_id IS NULL
            AND accounts.is_banned = FALSE
          GROUP BY accounts.id, s.id
          ORDER BY rank DESC
          LIMIT :limit OFFSET :offset
        SQL

        ADVANCED_SEARCH_WITHOUT_FOLLOWING = <<~SQL.squish
          SELECT
            accounts.*,
            #{Account::Search::BOOST} * ts_rank_cd(#{Account::Search::TEXT_SEARCH_RANKS}, to_tsquery('simple', :tsquery), 32) AS rank,
            count(f.id) AS followed
          FROM accounts
          LEFT OUTER JOIN follows AS f ON
            (accounts.id = f.account_id AND f.target_account_id = :id) OR (accounts.id = f.target_account_id AND f.account_id = :id)
          LEFT JOIN users ON accounts.id = users.account_id
          LEFT JOIN account_stats AS s ON accounts.id = s.account_id
          WHERE to_tsquery('simple', :tsquery) @@ #{Account::Search::TEXT_SEARCH_RANKS}
            AND accounts.suspended_at IS NULL
            AND accounts.moved_to_account_id IS NULL
            AND accounts.is_banned = FALSE
            AND (accounts.domain IS NOT NULL OR (users.approved = TRUE AND users.confirmed_at IS NOT NULL))
          GROUP BY accounts.id, s.id
          ORDER BY followed DESC, rank DESC
          LIMIT :limit OFFSET :offset
        SQL
      end

      class_methods do
        def search_for(terms, limit: Account::Search::DEFAULT_LIMIT, offset: 0)
          tsquery = generate_query_for_search(terms)

          find_by_sql([ BASIC_SEARCH_SQL, { limit: limit, offset: offset, tsquery: tsquery } ]).tap do |records|
            ActiveRecord::Associations::Preloader.new(records: records, associations: [ :account_stat, { user: :role } ]).call
          end
        end

        def advanced_search_for(terms, account, limit: Account::Search::DEFAULT_LIMIT, following: false, offset: 0)
          tsquery      = generate_query_for_search(terms)
          sql_template = following ? ADVANCED_SEARCH_WITH_FOLLOWING : ADVANCED_SEARCH_WITHOUT_FOLLOWING

          find_by_sql([ sql_template, { id: account.id, limit: limit, offset: offset, tsquery: tsquery } ]).tap do |records|
            ActiveRecord::Associations::Preloader.new(records: records, associations: [ :account_stat, { user: :role } ]).call
          end
        end
      end
    end
  end
end
