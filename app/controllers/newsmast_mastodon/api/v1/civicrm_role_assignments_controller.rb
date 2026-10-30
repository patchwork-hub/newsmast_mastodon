# frozen_string_literal: true

# GEM_SPLIT[AUTH-04]: DISABLED at cutover (2026-10-30) — unrouted; Gem B's
# PatchworkExtensions::Api::V1::CivicrmRoleAssignmentsController serves
# POST /api/v1/civicrm_role_assign. Retained until the verification window
# closes; then remove this file.
module NewsmastMastodon::Api::V1
  class CivicrmRoleAssignmentsController < ::Api::BaseController
    include ::NewsmastMastodon::Concerns::ApiResponseHelper

    before_action -> { doorkeeper_authorize! :write }
    before_action :require_user!

    # POST /api/v1/civicrm_role_assign
    def create
      return render_forbidden unless role_assignment_enabled?

      NewsmastMastodon::CivicrmRoleAssignmentWorker.perform_async(current_user.id)
      render_success({}, "api.messages.success", :accepted)
    rescue StandardError => e
      Rails.logger.error("CiviCRM role assignment enqueue failed: #{e.class}")
      render_internal_error
    end

    private

    def role_assignment_enabled?
      ActiveModel::Type::Boolean.new.cast(ENV.fetch("CSID_ROLE_ASSIGNMENT_ENABLED", "false"))
    end
  end
end
