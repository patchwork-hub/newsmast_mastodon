module NewsmastMastodon::Api::V1::Accounts
  class PatchworkSettingsController < ::Api::BaseController
    include ::NewsmastMastodon::Concerns::ApiResponseHelper
    before_action -> { doorkeeper_authorize! :read, :write }
    before_action :require_user!
    before_action :set_account
    before_action :validate_or_set_app_name

    # get push notification settings for leicester_news
    def leicester_news_notification
      @patchwork_setting = NewsmastMastodon::PatchworkSetting.find_by(account: @account, app_name: @app_name)
      settings_hash = @patchwork_setting&.settings || {}
      is_allowed = settings_hash.dig("leicester_notification") || false

      render_success({ leicester_notification: is_allowed }, "api.messages.success", :ok)
    end

    # update push notification settings for leicester_news
    def update_leicester_news_notification
      is_allowed = ActiveModel::Type::Boolean.new.cast(leicester_notification_params[:allowed])
      @patchwork_setting = NewsmastMastodon::PatchworkSetting.find_or_initialize_by(account: @account, app_name: @app_name)
      current_settings = (@patchwork_setting.settings || {}).with_indifferent_access
      updated_settings = current_settings.deep_merge(
        leicester_notification: is_allowed
      )

      if @patchwork_setting.update(settings: updated_settings)
        render_success({ leicester_notification: is_allowed }, "api.messages.success", :ok)
      else
        render_errors("api.errors.unprocessable_entity", :unprocessable_entity)
      end
    end

    # get article notifications setting
    def article_notifications
      @patchwork_setting = NewsmastMastodon::PatchworkSetting.find_by(account: @account, app_name: @app_name)
      settings_hash = @patchwork_setting&.settings || {}
      is_allowed = settings_hash.dig("article_notifications") || false

      render_success({ article_notifications: is_allowed }, "api.messages.success", :ok)
    end

    # update article notifications setting
    def update_article_notifications
      is_allowed = ActiveModel::Type::Boolean.new.cast(article_notifications_params[:allowed])
      @patchwork_setting = NewsmastMastodon::PatchworkSetting.find_or_initialize_by(account: @account, app_name: @app_name)
      current_settings = (@patchwork_setting.settings || {}).with_indifferent_access
      updated_settings = current_settings.deep_merge(
        article_notifications: is_allowed
      )

      if @patchwork_setting.update(settings: updated_settings)
        render_success({ article_notifications: is_allowed }, "api.messages.success", :ok)
      else
        render_errors("api.errors.unprocessable_entity", :unprocessable_entity)
      end
    end

    private

    def leicester_notification_params
      params.permit(:allowed)
    end

    def article_notifications_params
      params.permit(:allowed)
    end

    def app_name_params
      params.permit(:app_name)
    end

    def set_account
      @account = current_account
    end

    def validate_or_set_app_name
      app_name_param = app_name_params[:app_name]
      if app_name_param.blank?
        @app_name = NewsmastMastodon::PatchworkSetting.column_defaults["app_name"]
      elsif NewsmastMastodon::PatchworkSetting.app_names.key?(app_name_param)
        @app_name = app_name_param
      else
        render_errors("Invalid app name provided", :bad_request, {
          valid_options: NewsmastMastodon::PatchworkSetting.app_names.keys,
          attribute: app_name_param
        })
      end
    end
  end
end
