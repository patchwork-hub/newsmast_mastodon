# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::WaitList, type: :model do
  it "requires :invitation_code on create" do
    validators = described_class.validators_on(:invitation_code)
    expect(validators.map(&:class)).to include(ActiveRecord::Validations::PresenceValidator)
  end

  it "defines :channel_type enum" do
    expect(NewsmastMastodon::WaitList.channel_types.keys).to contain_exactly("channel", "hub")
  end

  it "generates a 6-digit invitation code" do
    record = described_class.new
    allow(described_class).to receive(:exists?).and_return(false)

    record.generate_invitation_code

    expect(record.invitation_code).to match(/\A\d{6}\z/)
  end

  it "retries invitation code generation on collision" do
    record = described_class.new
    allow(SecureRandom).to receive(:random_number).with(100_000..999_999).and_return(123_456, 654_321)
    allow(described_class).to receive(:exists?).with(invitation_code: "123456").and_return(true)
    allow(described_class).to receive(:exists?).with(invitation_code: "654321").and_return(false)

    record.generate_invitation_code

    expect(record.invitation_code).to eq("654321")
  end
end
