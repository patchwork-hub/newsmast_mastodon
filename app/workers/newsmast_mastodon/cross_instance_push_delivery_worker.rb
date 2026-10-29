# frozen_string_literal: true

module NewsmastMastodon
  # Sending side: delivers the outbound request in the background with retries,
  # so a partner instance being briefly unreachable doesn't block the caller.
  class CrossInstancePushDeliveryWorker
    include Sidekiq::Worker
    sidekiq_options queue: "push", retry: 5

    def perform(username, title, body, data = {})
      Rails.logger.info "<<<< Delivering cross-instance push to #{username} >>>>"
      NewsmastMastodon::CrossInstancePushClient.deliver(username: username, title: title, body: body, data: data)
    end
  end
end
