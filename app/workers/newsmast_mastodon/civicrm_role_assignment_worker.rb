# frozen_string_literal: true

module NewsmastMastodon
  class CivicrmRoleAssignmentWorker
    include Sidekiq::Worker

    ROLE_NAMES_BY_GROUP_ID = {
      15 => "Committee member",
      16 => "WG member",
      3 => "Staff"
    }.freeze

    sidekiq_options queue: "default", retry: 3

    def self.role_name_for(group_id)
      ROLE_NAMES_BY_GROUP_ID[group_id]
    end

    def perform(user_id, force_remote = false)
      user = User.find_by(id: user_id)
      return unless user
      return if user.role_id.present? || user.email.blank?

      result = NewsmastMastodon::CivicrmRoleCheckService.new(user.email, force_remote: force_remote).call
      return if result.values.blank?

      role_name = self.class.role_name_for(result.group_id)
      return if role_name.blank?

      escaped_role_name = ActiveRecord::Base.sanitize_sql_like(role_name.downcase)
      role = UserRole.where("LOWER(name) LIKE ?", "%#{escaped_role_name}%").first
      unless role
        Rails.logger.error("CiviCRM role assignment skipped: UserRole '#{role_name}' not found")
        return
      end

      User.where(id: user.id, role_id: nil).update_all(role_id: role.id, updated_at: Time.current)
    end
  end
end
