# frozen_string_literal: true

module NewsmastMastodon
  class PatchworkStatusReaction < ApplicationRecord
    self.table_name = 'patchwork_status_reactions'

    belongs_to :account
    belongs_to :status

    validates :name, presence: true
    validates_with PatchworkStatusReactionValidator
  end
end
