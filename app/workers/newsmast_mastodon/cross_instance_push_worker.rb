# frozen_string_literal: true

module NewsmastMastodon
  # Receiving side: delivers a push notification requested by a partner instance.
  class CrossInstancePushWorker
    include Sidekiq::Worker
    sidekiq_options queue: "push", retry: 5

    def perform(username, title, body, data = {})
      puts "Performing CrossInstancePushWorker with username=#{username}, title=#{title}, body=#{body}, data=#{data}"
      NewsmastMastodon::CrossInstancePushService.new.call(username, title, body, data)
    rescue => e
      Rails.logger.error "[CrossInstancePushWorker] Error processing: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end
end
