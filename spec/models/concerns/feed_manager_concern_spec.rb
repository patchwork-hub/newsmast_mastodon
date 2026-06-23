# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe NewsmastMastodon::Concerns::FeedManagerConcern, type: :model do
  it "is a module" do
    expect(described_class).to be_a(Module)
  end

  it "defines push_to_custom, unpush_from_custom, populate_custom" do
    methods = described_class.instance_methods(false)
    expect(methods).to include(:push_to_custom, :unpush_from_custom, :populate_custom)
  end

  it "#push_to_custom returns false when account has no recent sign-in" do
    obj = Object.new
    obj.extend(described_class)

    account = instance_double("Account")
    user = instance_double("User", signed_in_recently?: false)
    allow(account).to receive(:user).and_return(user)
    status = instance_double("Status")

    expect(obj.push_to_custom(account, status)).to be false
  end

  it "#unpush_from_custom returns false when CommunityAdmin table absent" do
    obj = Object.new
    obj.extend(described_class)

    account = instance_double("Account")
    status = instance_double("Status")
    # Replace real AR class with a pure stub to avoid DB metadata lookup
    fake_admin = Module.new { def self.table_exists?; false; end }
    stub_const("NewsmastMastodon::CommunityAdmin", fake_admin)

    expect(obj.unpush_from_custom(account, status)).to be false
  end
end
