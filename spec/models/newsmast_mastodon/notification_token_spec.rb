# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe NewsmastMastodon::NotificationToken, type: :model do
  it "uses the patchwork_notification_tokens table" do
    expect(described_class.table_name).to eq("patchwork_notification_tokens")
  end

  it "validates presence of :platform_type" do
    validators = described_class.validators_on(:platform_type)
    expect(validators.map(&:class)).to include(ActiveRecord::Validations::PresenceValidator)
  end

  it "validates uniqueness of :notification_token scoped to account_id" do
    validators = described_class.validators_on(:notification_token)
    uniqueness = validators.find { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
    expect(uniqueness).not_to be_nil
    expect(uniqueness.options[:scope]).to eq(:account_id)
  end

  it "belongs_to :account" do
    ref = described_class.reflect_on_association(:account)
    expect(ref).not_to be_nil
    expect(ref.macro).to eq(:belongs_to)
  end
end
