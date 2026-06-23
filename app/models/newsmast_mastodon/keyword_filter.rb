# frozen_string_literal: true

module NewsmastMastodon
  class KeywordFilter < ApplicationRecord
    self.table_name = "keyword_filters"

    enum :filter_type, { content: 0, hashtag: 1, both: 2 }
  end
end
