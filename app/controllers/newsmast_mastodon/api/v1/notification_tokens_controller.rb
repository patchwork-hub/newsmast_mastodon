# frozen_string_literal: true

module NewsmastMastodon::Api::V1
  class NotificationTokensController < ::Api::BaseController
    include ::NewsmastMastodon::Concerns::ApiResponseHelper

    before_action :require_user!
    before_action -> { doorkeeper_authorize! :read, :write }
    before_action :set_notification_token, only: [ :create, :revoke_notification_token ]
    before_action :set_platform_tokens, only: [ :reset_device_tokens ]
    before_action :fetch_notification_tokens, only: [ :update_mute, :get_mute_status ]

    rescue_from ArgumentError do |e|
      render_error(e.to_s, :unprocessable_entity)
    end

    def create
      if @notification_token.present?
        render_result({}, "api.notification.messages.token_already_exists")
      else
        NewsmastMastodon::NotificationToken.create!(notification_token_params.merge(account_id: current_account.id))
        render_success({}, "api.notification.messages.token_saved")
      end
    end

    def revoke_notification_token
      if @notification_token.present?
        @notification_token.destroy!
        render_deleted("api.notification.messages.token_deleted")
      else
        render_result({}, "api.errors.not_found", :not_found)
      end
    end

    def get_mute_status
      if @notification_tokens.present?
        render_response(key: :mute, data: @notification_tokens.first.mute, status: :ok)
      else
        render_result({}, "api.notification.messages.token_not_found", :not_found)
      end
    end

    def update_mute
      if @notification_tokens.present?
        @notification_tokens.update_all(mute: notification_token_params[:mute])
        render_updated({}, "api.notification.messages.mute_updated")
      else
        render_result({}, "api.notification.messages.token_not_found", :not_found)
      end
    end

    def reset_device_tokens
      if @notification_tokens.present?
        @notification_tokens.destroy_all
        render_deleted("api.notification.messages.token_deleted")
      else
        render_result({}, "api.errors.not_found", :not_found)
      end
    end

    private

    def set_notification_token
      @notification_token = NewsmastMastodon::NotificationToken.find_by(notification_token: notification_token_params[:notification_token], account_id: current_account.id)
    end

    def notification_token_params
      params.permit(:notification_token, :platform_type, :mute)
    end

    def fetch_notification_tokens
      @notification_tokens = NewsmastMastodon::NotificationToken.where(account_id: current_account.id)
    end

    def set_platform_tokens
      @notification_tokens = NewsmastMastodon::NotificationToken.where(platform_type: notification_token_params[:platform_type], account_id: current_account.id)
    end
  end
end
