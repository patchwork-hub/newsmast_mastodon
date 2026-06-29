# frozen_string_literal: true

module NewsmastMastodon
  class KeywordFilterGroup < ApplicationRecord
    self.table_name = "keyword_filter_groups"

    belongs_to :server_setting, class_name: "NewsmastMastodon::ServerSetting", optional: true
    has_many :keyword_filters, class_name: "NewsmastMastodon::KeywordFilter", dependent: :destroy

    validates :name, presence: true
  end
end
