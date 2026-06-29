# frozen_string_literal: true

# Namespace update: Posts::ServerSetting → NewsmastMastodon::ServerSetting
module LongPost
  module StatusLengthValidatorPatch
    include PatchworkHelper

    DEFAULT_MAX_CHARS = 500

    def self.prepended(base)
      base.class_eval do
        def validate(status)
          return unless status.local? && !status.reblog?
          max_chars = get_max_chars
          status.errors.add(:text, I18n.t("statuses.over_character_limit", max: max_chars)) if too_long?(status)
        end

        private

        def too_long?(status)
          max_chars = get_max_chars
          countable_length(combined_text(status)) > max_chars
        end

        def get_max_chars
          return DEFAULT_MAX_CHARS unless patchwork_server_settings_exist?

          begin
            long_post = NewsmastMastodon::ServerSetting.get_long_post("Long posts")

            return DEFAULT_MAX_CHARS if long_post.nil?
            return DEFAULT_MAX_CHARS unless long_post.value

            optional_value = long_post.optional_value
            return DEFAULT_MAX_CHARS if optional_value.nil? || optional_value.to_s.strip.empty?

            max_chars = optional_value.to_i
            return DEFAULT_MAX_CHARS if max_chars <= 0

            max_chars
          rescue ActiveRecord::RecordNotFound
            DEFAULT_MAX_CHARS
          rescue ActiveRecord::StatementInvalid
            DEFAULT_MAX_CHARS
          rescue NoMethodError
            DEFAULT_MAX_CHARS
          rescue StandardError
            DEFAULT_MAX_CHARS
          end
        end
      end
    end
  end
end
