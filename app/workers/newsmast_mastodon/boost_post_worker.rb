# frozen_string_literal: true


module NewsmastMastodon
  class BoostPostWorker
    include Sidekiq::Worker
    sidekiq_options queue: "default", retry: false, dead: true

    def perform(post_url)
      NewsmastMastodon::BoostPostService.new(post_url).call
    rescue => e
      Rails.logger.error "[BoostPostWorker] Error processing #{post_url}: #{e.class} - #{e.message}"
      { status: :error, error: e.message }
    end
  end
end
