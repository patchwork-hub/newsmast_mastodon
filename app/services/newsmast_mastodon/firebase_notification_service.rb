# frozen_string_literal: true


require "googleauth"
require "httparty"

module NewsmastMastodon
  class FirebaseNotificationService
    include HTTParty

    BASE_URL = if ENV["FIREBASE_PROJECT_ID"].present?
      "https://fcm.googleapis.com/v1/projects/#{ENV['FIREBASE_PROJECT_ID']}/messages:send"
    else
      nil
    end

    FILE_NAME = if ENV["FIREBASE_KEY_FILE_NAME"].present?
      ENV["FIREBASE_KEY_FILE_NAME"]
    else
      nil
    end

    class << self
      def send_notification(token, title, body, data = {})
        if BASE_URL.blank?
          Rails.logger.error("Firebase notifications are disabled: FIREBASE_PROJECT_ID environment variable is not set")
          return nil
        end

        if FILE_NAME.blank?
          Rails.logger.error("FIREBASE_KEY_FILE_NAME environment variable is not set")
          return nil
        end

        service_account_file = Rails.root.join("config", FILE_NAME)
        unless File.exist?(service_account_file)
          Rails.logger.error("Service account file not found at #{service_account_file}")
          return nil
        end

        access_token = fetch_access_token(service_account_file)
        return nil if access_token.blank?

        headers = {
          "Authorization" => "Bearer #{access_token}",
          "Content-Type" => "application/json"
        }

        payload = {
          message: {
            token: token,
            notification: {
              title: title,
              body: body
            },
            data: data
          }
        }.to_json
        response = post(BASE_URL, headers: headers, body: payload)

        Rails.logger.error("Error sending notification: #{response.body}") unless response.success?

        response
      rescue StandardError => e
        Rails.logger.error("Exception sending notification: #{e.message}")
        nil
      end

      def reset_authorizer_cache!
        @firebase_authorizer = nil
        @firebase_access_token = nil
        @firebase_access_token_expiry = nil
      end

      private

      def fetch_access_token(service_account_file)
        now = Time.current.to_i

        @firebase_authorizer_lock ||= Mutex.new
        @firebase_authorizer_lock.synchronize do
          if @firebase_authorizer.nil? || @firebase_access_token_expiry.to_i <= now + 60
            @firebase_authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
              json_key_io: File.open(service_account_file),
              scope: "https://www.googleapis.com/auth/firebase.messaging"
            )
            token_data = @firebase_authorizer.fetch_access_token!
            @firebase_access_token = token_data["access_token"]
            @firebase_access_token_expiry = now + (token_data["expires_in"] || 3600).to_i
          end

          @firebase_access_token
        end
      end
    end
  end
end
