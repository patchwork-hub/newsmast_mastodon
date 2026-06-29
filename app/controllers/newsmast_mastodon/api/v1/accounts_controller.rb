# frozen_string_literal: true

module NewsmastMastodon::Api::V1
  class AccountsController < ::Api::BaseController
    include Redisable if defined?(Redisable)
    include ::NewsmastMastodon::Concerns::ApiResponseHelper

    before_action :require_user!
    before_action -> { doorkeeper_authorize! :read, :write }

    def delete_account
      if current_user.valid_password?(account_params[:password])
        current_account.suspend!(origin: :local, block_email: false)
        AccountDeletionWorker.perform_async(current_user.account_id, { "reserve_username" => true })
        sign_out
        render_success(data = {}, message_key = "api.messages.deleted", status = :ok, additional_params = {})
      else
        render_result({}, "api.account.errors.password_incorrect", :unprocessable_entity)
      end
    end

    private

    def account_params
      params.permit(:password)
    end
  end
end
