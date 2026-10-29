# frozen_string_literal: true

# GEM_SPLIT[AUTH-06]: DISABLED at cutover (2026-10-13) —
# `DELETE /api/v1/patchwork/account_deletion/:id` is now served by
# PatchworkExtensions::Api::V1::Patchwork::AccountDeletionController (Gem B).
# Remove this controller after host verification passes.
module NewsmastMastodon::Api::V1::Patchwork
  class AccountDeletionController < ::Api::BaseController
    include ::NewsmastMastodon::Concerns::ApiResponseHelper

    before_action -> { doorkeeper_authorize! :read, :write }
    before_action :require_user!
    before_action :set_account, only: [ :destroy ]

    def destroy
      if @account.nil?
        render_error("api.errors.not_found", :not_found)
        return
      end

      DeleteAccountService.new.call(@account, reserve_email: false, reserve_username: false)
      render_success({}, "api.messages.deleted", :accepted)
    end

    private

    def set_account
      @account = Account.find_by(id: params[:id])
    end
  end
end
