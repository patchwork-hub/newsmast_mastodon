# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::BoostLamdaNewsmastService, type: :service do
  it "sends a Lambda boost request (HTTParty stub)" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("BOOST_COMMUNITY_BOT_URL", nil).and_return("https://lambda.example/boost")
    allow(ENV).to receive(:fetch).with("BOOST_COMMUNITY_BOT_API_KEY", nil).and_return("key-1")

    response = instance_double("HTTPartyResponse")
    allow(HTTParty).to receive(:post).and_return(response)

    result = described_class.new.boost_status("channelbot", 12, "https://example.org/@a/12")

    expect(HTTParty).to have_received(:post).with(
      "https://lambda.example/boost",
      body: kind_of(String),
      headers: {
        "Content-Type" => "application/json",
        "x-api-key" => "key-1"
      }
    )
    expect(result).to eq(response)
  end
end
