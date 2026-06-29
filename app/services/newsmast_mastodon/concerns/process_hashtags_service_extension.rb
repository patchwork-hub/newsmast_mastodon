# frozen_string_literal: true


module NewsmastMastodon
  module Concerns
    module ProcessHashtagsServiceExtension
      extend ActiveSupport::Concern

      def call(status, raw_tags = [])
        super(status, raw_tags)

        if ENV["REBLOG_ENABLED"].present? && ENV["REBLOG_ENABLED"].to_s.downcase == "true"
          reblog_posts(status)
        end
      end

      private

      def reblog_posts(status)
        return unless status.created_at == status.updated_at
        if status.local? && status.tags.present? && status.visibility == "public"
          return unless ENV.values_at("REBLOG_INSTANCE_URL", "REBLOG_EMAIL", "REBLOG_PASSWORD", "REBLOG_CLIENT_ID", "REBLOG_CLIENT_SECRET").all?(&:present?)
          status_url = ActivityPub::TagManager.instance.url_for(status)
          return unless status_url

          NewsmastMastodon::ReblogPostWorker.perform_async(status_url)
        end
      end
    end
  end
end
