# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::CommunityAdmin, type: :model do
  it "belongs_to :community" do
    ref = NewsmastMastodon::CommunityAdmin.reflect_on_association(:community)
    expect(ref).not_to be_nil
    expect(ref.macro).to eq(:belongs_to)
    expect(ref.options[:foreign_key]).to eq("patchwork_community_id")
  end

  it "belongs_to :account (Mastodon host)" do
    ref = described_class.reflect_on_association(:account)
    expect(ref).not_to be_nil
    expect(ref.macro).to eq(:belongs_to)
  end

  it "defines :account_status enum (active/suspended/deleted)" do
    expect(NewsmastMastodon::CommunityAdmin.account_statuses.keys).to contain_exactly("active", "suspended", "deleted")
  end

  it "uses the patchwork_communities_admins table" do
    expect(NewsmastMastodon::CommunityAdmin.table_name).to eq("patchwork_communities_admins")
  end

  it "exposes role constants for admin assignment endpoints" do
    expect(described_class::GROUP_ROLES).to contain_exactly("GroupAdmin", "GroupModerator")
    expect(described_class::ROLES).to include("OrganisationAdmin", "UserAdmin", "HubAdmin", "NewsmastAdmin")
  end

  it "validates role inclusion when role is present" do
    record = described_class.new(role: "NotARole")

    expect(record).not_to be_valid
    expect(record.errors[:role]).to be_present
  end

  it "allows blank role for compatibility with legacy rows" do
    record = described_class.new(role: nil)

    record.validate

    expect(record.errors[:role]).to be_blank
  end

  it "defines an active_group_roles scope" do
    expect(described_class).to respond_to(:active_group_roles)
  end
end
