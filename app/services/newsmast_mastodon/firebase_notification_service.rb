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

    def self.send_notification(token, title, body, data = {})
      if BASE_URL.blank?
        Rails.logger.error("Firebase notifications are disabled: FIREBASE_PROJECT_ID environment variable is not set")
        return nil
      end

      if FILE_NAME.blank?
        Rails.logger.error("FIREBASE_KEY_FILE_NAME environment variable is not set")
        return nil
      end

      # Path to your service account JSON file
      service_account_file = Rails.root.join("config", FILE_NAME)
      unless File.exist?(service_account_file)
        Rails.logger.error("Service account file not found at #{service_account_file}")
        return nil
      end

      # Define the required scope
      scope = "https://www.googleapis.com/auth/firebase.messaging"

      # Authenticate and get the token
      authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(service_account_file),
        scope: scope
      )

      # Fetch the access token
      access_token = authorizer.fetch_access_token!["access_token"]

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
  end
end
