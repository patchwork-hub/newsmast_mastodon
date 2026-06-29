# frozen_string_literal: true


module NewsmastMastodon
  class ReblogPostWorker
    include Sidekiq::Worker
    sidekiq_options queue: "default", retry: false, dead: true

    def perform(status_url)
      NewsmastMastodon::ReblogPostService.new(status_url).call
    rescue => e
      Rails.logger.error "[ReblogPostWorker] Error processing #{status_url}: #{e.class} - #{e.message}"
      { status: :error, error: e.message }
    end
  end
end
