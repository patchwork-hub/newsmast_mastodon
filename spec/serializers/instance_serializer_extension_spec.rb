# frozen_string_literal: true

require "rails_helper"
require File.expand_path("../../app/serializers/long_post/instance_serializer_extension", __dir__)

RSpec.describe LongPost::InstanceSerializerExtension, type: :serializer do
  let(:serializer) do
    serializer_class = Class.new do
      def configuration
        { media_attachments: { image_size_limit: 10_485_760 } }
      end
    end
    serializer_class.prepend(described_class)
    serializer_class.new
  end

  before do
    unless defined?(StatusLengthValidator::URL_PLACEHOLDER_CHARS)
      stub_const("StatusLengthValidator", Class.new)
      stub_const("StatusLengthValidator::URL_PLACEHOLDER_CHARS", 23)
    end
  end

  it "advertises the character limit configured by the dashboard key" do
    NewsmastMastodon::ServerSetting.create!(key: "long_posts", name: "long_posts", value: true, optional_value: "3000")

    expect(serializer.configuration[:statuses][:max_characters]).to eq(3000)
    expect(serializer.configuration[:media_attachments]).to eq(image_size_limit: 10_485_760)
  end

  it "falls back to 500 when the setting is missing" do
    expect(serializer.configuration[:statuses][:max_characters]).to eq(500)
  end

  it "falls back to 500 when long posts are disabled" do
    NewsmastMastodon::ServerSetting.create!(key: "long_posts", name: "long_posts", value: false, optional_value: "3000")

    expect(serializer.configuration[:statuses][:max_characters]).to eq(500)
  end

  [ nil, "0", "-1", "invalid" ].each do |limit|
    it "falls back to 500 for an invalid limit of #{limit.inspect}" do
      NewsmastMastodon::ServerSetting.create!(key: "long_posts", name: "long_posts", value: true, optional_value: limit)

      expect(serializer.configuration[:statuses][:max_characters]).to eq(500)
    end
  end
end
