# frozen_string_literal: true

require "rails_helper"
require File.expand_path("../../app/validators/long_post/status_length_validator_patch", __dir__)

RSpec.describe LongPost::StatusLengthValidatorPatch, type: :validator do
  let(:validator) do
    validator_class = Class.new(ActiveModel::Validator) do
      def countable_length(text)
        text.each_grapheme_cluster.size
      end

      def combined_text(status)
        [ status.spoiler_text, status.text ].join
      end
    end
    validator_class.prepend(described_class)
    validator_class.new
  end

  let(:status) do
    double("status", local?: true, reblog?: false, text: "a" * 1000, spoiler_text: "", errors: double("errors", add: nil))
  end

  it "accepts posts up to the configured character limit" do
    NewsmastMastodon::ServerSetting.create!(key: "long_posts", name: "long_posts", value: true, optional_value: "1000")

    expect(status.errors).not_to receive(:add)
    validator.validate(status)
  end

  it "rejects posts exceeding the configured character limit" do
    NewsmastMastodon::ServerSetting.create!(key: "long_posts", name: "long_posts", value: true, optional_value: "999")

    expect(status.errors).to receive(:add).with(:text, I18n.t("statuses.over_character_limit", max: 999))
    validator.validate(status)
  end

  it "uses the updated limit without recreating the validator" do
    setting = NewsmastMastodon::ServerSetting.create!(key: "long_posts", name: "long_posts", value: true, optional_value: "1000")
    validator.validate(status)
    setting.update!(optional_value: "999")

    expect(status.errors).to receive(:add).with(:text, I18n.t("statuses.over_character_limit", max: 999))
    validator.validate(status)
  end

  it "falls back to 500 when the setting is missing" do
    expect(status.errors).to receive(:add).with(:text, I18n.t("statuses.over_character_limit", max: 500))
    validator.validate(status)
  end

  it "falls back to 500 when long posts are disabled" do
    NewsmastMastodon::ServerSetting.create!(key: "long_posts", name: "long_posts", value: false, optional_value: "1000")

    expect(status.errors).to receive(:add).with(:text, I18n.t("statuses.over_character_limit", max: 500))
    validator.validate(status)
  end

  it "does not validate remote posts or boosts" do
    allow(status).to receive(:local?).and_return(false)
    expect(status.errors).not_to receive(:add)
    validator.validate(status)

    allow(status).to receive_messages(local?: true, reblog?: true)
    validator.validate(status)
  end
end
