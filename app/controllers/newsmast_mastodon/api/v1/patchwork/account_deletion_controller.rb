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
