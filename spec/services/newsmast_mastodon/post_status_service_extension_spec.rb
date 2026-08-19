# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::Overrides::PostStatusServiceExtension, type: :service do
  let(:process_service) { instance_double("ProcessHashtagsService", call: true) }

  let(:service_class) do
    process = process_service

    Class.new do
      include NewsmastMastodon::Overrides::PostStatusServiceExtension

      def initialize(status, process)
        @status = status
        @process = process
        @media = []
        @options = {}
      end

      def call_postprocess!
        send(:postprocess_status!)
      end

      private

      def process_hashtags_service
        @process
      end

      def process_email_subscriptions!
        true
      end
    end
  end

  it "skips ActivityPub distribution when status is local_only" do
    status = instance_double(
      "Status",
      id: 42,
      local_only?: true,
      poll: nil,
      quote: nil
    )

    stub_const("LinkCrawlWorker", class_double("LinkCrawlWorker", perform_async: true))
    stub_const("DistributionWorker", class_double("DistributionWorker", perform_async: true))
    stub_const("PollExpirationNotifyWorker", class_double("PollExpirationNotifyWorker", perform_at: true))

    stub_const("Trends", Module.new)
    trends_tags = instance_double("Trends::Tags", register: true)
    Trends.define_singleton_method(:tags) { trends_tags }

    stub_const("ActivityPub", Module.new)
    activitypub_distribution = class_double("ActivityPub::DistributionWorker", perform_async: true)
    activitypub_quote_request = class_double("ActivityPub::QuoteRequestWorker", perform_async: true)
    ActivityPub.const_set(:DistributionWorker, activitypub_distribution)
    ActivityPub.const_set(:QuoteRequestWorker, activitypub_quote_request)

    ban_worker = class_double("NewsmastMastodon::BanStatusWorker", perform_async: true)
    stub_const("NewsmastMastodon::BanStatusWorker", ban_worker)

    service = service_class.new(status, process_service)
    service.call_postprocess!

    expect(DistributionWorker).to have_received(:perform_async).with(42)
    expect(ActivityPub::DistributionWorker).not_to have_received(:perform_async)
  end
end
