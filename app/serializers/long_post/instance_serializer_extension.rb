# frozen_string_literal: true

# Namespace update: Posts::ServerSetting → NewsmastMastodon::ServerSetting
module LongPost
  module InstanceSerializerExtension
    DEFAULT_MAX_CHARS = 500

    def configuration
      super.merge(
        statuses: {
          max_characters: get_max_chars,
          max_media_attachments: 4,
          characters_reserved_per_url: StatusLengthValidator::URL_PLACEHOLDER_CHARS
        }
      )
    end

    private

    def get_max_chars
      return DEFAULT_MAX_CHARS unless Object.const_defined?("NewsmastMastodon::ServerSetting")

      begin
        long_post = NewsmastMastodon::ServerSetting.get_long_post("Long posts")

        return DEFAULT_MAX_CHARS if long_post.nil?
        return DEFAULT_MAX_CHARS unless long_post.value

        optional_value = long_post.optional_value
        return DEFAULT_MAX_CHARS if optional_value.nil? || optional_value.to_s.strip.empty?

        max_chars = optional_value.to_i
        return DEFAULT_MAX_CHARS if max_chars <= 0

        max_chars
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.warn("Long posts setting not found: #{e.message}")
        DEFAULT_MAX_CHARS
      rescue ActiveRecord::StatementInvalid => e
        Rails.logger.error("Database error in get_max_chars: #{e.message}")
        DEFAULT_MAX_CHARS
      rescue NoMethodError => e
        Rails.logger.error("Method error in get_max_chars (possible nil reference): #{e.message}")
        DEFAULT_MAX_CHARS
      rescue StandardError => e
        Rails.logger.error("Unexpected error in get_max_chars: #{e.class} - #{e.message}")
        DEFAULT_MAX_CHARS
      end
    end
  end
end
