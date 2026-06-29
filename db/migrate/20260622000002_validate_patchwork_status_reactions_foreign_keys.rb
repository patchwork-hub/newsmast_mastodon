# frozen_string_literal: true

class ValidatePatchworkStatusReactionsForeignKeys < ActiveRecord::Migration[7.1]
  def change
    validate_foreign_key :patchwork_status_reactions, :accounts
    validate_foreign_key :patchwork_status_reactions, :statuses
  end
end
