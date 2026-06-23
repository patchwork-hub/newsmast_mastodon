# frozen_string_literal: true

# Deep link configuration for iOS Universal Links and Android App Links.
#
# All configuration is done via environment variables (no hardcoded defaults):
#
# iOS (required for apple-app-site-association):
#   IOS_APP_ID                        - Full app identifier, e.g. "VA45Q6RWV3.com.csidnetwork.social"
#   IOS_DEEPLINK_PATHS                - Comma-separated path patterns (optional, defaults to "/@*,/@*/*")
#
# Android (required for assetlinks.json):
#   ANDROID_PACKAGE_NAME              - Package name, e.g. "com.csidnetwork.social"
#   ANDROID_SHA256_CERT_FINGERPRINTS  - Comma-separated SHA-256 fingerprints
#
# If the required env vars are not set, the corresponding endpoint returns 404.

Rails.application.config.after_initialize do
  deep_links_config = {
    ios: {
      app_id: ENV["IOS_APP_ID"],
      paths: ENV.fetch("IOS_DEEPLINK_PATHS", "/@*,/@*/*").split(",").map(&:strip)
    },
    android: {
      package_name: ENV["ANDROID_PACKAGE_NAME"],
      sha256_cert_fingerprints: ENV["ANDROID_SHA256_CERT_FINGERPRINTS"]&.split(",")&.map(&:strip)
    }
  }

  Rails.application.config.x.deep_links = deep_links_config
end
