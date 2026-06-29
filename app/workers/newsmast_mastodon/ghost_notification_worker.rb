# frozen_string_literal: true


module NewsmastMastodon
  class GhostNotificationWorker
    include Sidekiq::Worker
    sidekiq_options queue: "default", retry: false, dead: true

    def perform(ghost_post_data)
      NewsmastMastodon::GhostNotificationService.new.call(ghost_post_data)
    rescue => e
      Rails.logger.error "[GhostNotificationWorker] Error processing : #{e.message}\n#{e.backtrace.join("\n")}"
      { status: :error, error: e.message }
    end
  end
end
