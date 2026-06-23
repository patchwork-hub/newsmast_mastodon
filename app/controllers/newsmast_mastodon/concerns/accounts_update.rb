# frozen_string_literal: true

module NewsmastMastodon::Concerns::AccountsUpdate
  extend ActiveSupport::Concern
  include NonChannelHelper

  def update
    @account = current_account
    UpdateAccountService.new.call(@account, account_params, raise_error: true)
    current_user.update(user_params) if user_params
    ActivityPub::UpdateDistributionWorker.perform_async(@account.id)
    NewsmastMastodon::UpdateChannelNameServices.new.call(@account, type: "channel_feed") unless is_non_channel?
    render json: @account, serializer: REST::CredentialAccountSerializer
  rescue ActiveRecord::RecordInvalid => e
    render json: ValidationErrorFormatter.new(e).as_json, status: 422
  end
end
