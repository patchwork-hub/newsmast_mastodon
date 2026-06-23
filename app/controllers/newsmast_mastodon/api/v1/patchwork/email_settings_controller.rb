# frozen_string_literal: true

module NewsmastMastodon::Api::V1::Patchwork
  class EmailSettingsController < ::Api::BaseController
    include ::NewsmastMastodon::Concerns::ApiResponseHelper
    include ::NewsmastMastodon::Concerns::EmailNotificationAttributesConcern

    before_action -> { doorkeeper_authorize! :read, :write }
    before_action :require_user!

    def index
      notification_emails = current_user.settings.as_json.select do |key, _|
        key.to_s.start_with?("notification_emails.")
      end
      notification_emails.delete(:'notification_emails.software_updates')
      all_same = notification_emails.values.uniq.size == 1
      result_variable = all_same ? notification_emails.values.first : true
      data = notification_emails.empty? ? false : result_variable
      render_success(data, "api.messages.success", :ok)
    end

    def email_notification
      settings = enable_email_notification? ? email_notification_attributes(enabled: true) : email_notification_attributes(enabled: false)
      if current_user.update(settings_attributes: settings)
        render_success({}, "api.messages.success", :ok)
      else
        render_error("api.errors.unprocessable_entity", :unprocessable_entity)
      end
    end

    private

    def enable_email_notification?
      truthy_param?(email_notification_params[:allowed])
    end

    def email_notification_params
      params.permit(:allowed)
    end

    def truthy_param?(key)
      ActiveModel::Type::Boolean.new.cast(key)
    end
  end
end
