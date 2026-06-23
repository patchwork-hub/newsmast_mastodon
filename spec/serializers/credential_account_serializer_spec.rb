# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::Overrides::CredentialAccountSerializer, type: :serializer do
  it "includes fields added by the override (source, role, etc.)" do
    user = instance_double(
      "User",
      setting_default_privacy: "public",
      setting_default_sensitive: false,
      setting_default_language: "en",
      email: "alice@example.org"
    )

    field = instance_double("Field", to_h: { name: "Website", value: "https://example.org" })
    account = instance_double(
      "Account",
      user: user,
      note: "bio",
      fields: [ field ],
      hide_collections: true,
      discoverable: true,
      indexable: false,
      attribution_domains: [ "example.org" ]
    )

    stub_const("FollowRequest", Class.new do
      def self.where(*); end
    end)

    relation = instance_double("FollowRequestRelation")
    limited = instance_double("FollowRequestLimited", count: 3)
    allow(FollowRequest).to receive(:where).with(target_account: account).and_return(relation)
    allow(relation).to receive(:limit).with(40).and_return(limited)

    serializer = Class.new do
      include NewsmastMastodon::Overrides::CredentialAccountSerializer

      attr_reader :object

      def initialize(object)
        @object = object
      end
    end.new(account)

    source = serializer.source

    expect(source[:privacy]).to eq("public")
    expect(source[:sensitive]).to be(false)
    expect(source[:language]).to eq("en")
    expect(source[:note]).to eq("bio")
    expect(source[:fields]).to eq([ { name: "Website", value: "https://example.org" } ])
    expect(source[:follow_requests_count]).to eq(3)
    expect(source[:hide_collections]).to be(true)
    expect(source[:discoverable]).to be(true)
    expect(source[:indexable]).to be(false)
    expect(source[:email]).to eq("alice@example.org")
    expect(source[:attribution_domains]).to eq([ "example.org" ])
  end
end
