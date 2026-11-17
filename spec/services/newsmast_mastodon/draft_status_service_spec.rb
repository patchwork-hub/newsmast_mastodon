# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::Concerns::DraftStatusService, type: :service do
  # Minimal stand-in for upstream PostStatusService (Mastodon 4.6.10) that
  # keeps the same `#call` control flow, so the hooks are exercised exactly
  # as they are in the host without copying `#call` into the gem.
  let(:base_class) do
    Class.new do
      attr_reader :log

      def call(account, options = {})
        @account = account
        @options = options
        @log = []

        preprocess_attributes!
        validate_media!

        if scheduled?
          schedule_status!
        else
          process_status!
        end

        unless scheduled?
          postprocess_status!
          bump_potential_friendship!
        end

        @status
      end

      private

      def preprocess_attributes!
        @scheduled_at = @options[:scheduled_at]
        @log << :preprocess
      end

      def validate_media!; end

      def scheduled?
        @scheduled_at.present?
      end

      def schedule_status!
        @status = :scheduled
      end

      def process_status!
        @status = :published
      end

      def postprocess_status!
        @log << :postprocess
      end

      def bump_potential_friendship!
        @log << :bump
      end

      def idempotency_duplicate
        :upstream_duplicate
      end
    end
  end

  let(:service_class) do
    prepended = Class.new(base_class).prepend(described_class)
    # Stub persistence in a subclass so it wins over the prepended module.
    Class.new(prepended) do
      private

      def draft_status!
        @status = :drafted
      end
    end
  end

  it "does not redefine PostStatusService#call (no full-method copy)" do
    expect(described_class.instance_methods(false)).not_to include(:call)
    expect(described_class.private_instance_methods(false)).not_to include(:call)
  end

  it "keeps upstream preprocessing and records the drafted flag" do
    service = service_class.new
    service.call(:account, drafted: true)

    expect(service.log).to include(:preprocess)
    expect(service.send(:drafted?)).to be(true)
  end

  it "creates a draft and skips post-processing when drafted" do
    service = service_class.new

    expect(service.call(:account, drafted: true)).to eq(:drafted)
    expect(service.log).not_to include(:postprocess, :bump)
  end

  it "publishes normally and post-processes when not drafted" do
    service = service_class.new

    expect(service.call(:account, {})).to eq(:published)
    expect(service.log).to include(:postprocess, :bump)
  end

  it "lets scheduling win over drafting, as before" do
    service = service_class.new

    expect(service.call(:account, drafted: true, scheduled_at: 1.day.from_now)).to eq(:scheduled)
  end

  it "defers to upstream idempotency_duplicate when not drafted" do
    service = service_class.new
    service.call(:account, {})

    expect(service.send(:idempotency_duplicate)).to eq(:upstream_duplicate)
  end

  it "looks up idempotency duplicates among drafted statuses when drafted" do
    drafts = double("drafts")
    account = double("Account", patchwork_drafted_statuses: drafts)
    allow(drafts).to receive(:find).with("123").and_return(:existing_draft)

    service = service_class.new
    service.call(account, drafted: true)
    service.instance_variable_set(:@idempotency_duplicate, "123")

    expect(service.send(:idempotency_duplicate)).to eq(:existing_draft)
  end

  context "with the Mastodon host loaded" do
    before { require_host! }

    let(:account) { Fabricate(:account) }

    it "returns the same status for a double submit with the same Idempotency-Key" do
      first  = PostStatusService.new.call(account, text: "hello", idempotency: "same-key")
      second = PostStatusService.new.call(account, text: "hello", idempotency: "same-key")

      expect(second).to eq(first)
      expect(account.statuses.count).to eq(1)
    end

    it "returns the same draft for a double submit with the same Idempotency-Key" do
      first  = PostStatusService.new.call(account, text: "draft", drafted: true, idempotency: "draft-key")
      second = PostStatusService.new.call(account, text: "draft", drafted: true, idempotency: "draft-key")

      expect(first).to be_a(NewsmastMastodon::DraftedStatus)
      expect(second).to eq(first)
      expect(account.patchwork_drafted_statuses.count).to eq(1)
      expect(account.statuses.count).to eq(0)
    end
  end
end
