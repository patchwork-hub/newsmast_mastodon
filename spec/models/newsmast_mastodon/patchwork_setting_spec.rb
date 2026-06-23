# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe NewsmastMastodon::PatchworkSetting, type: :model do
  it "uses the patchwork_settings table" do
    expect(described_class.table_name).to eq("patchwork_settings")
  end

  it "defines :app_name enum" do
    expect(described_class.app_names.keys).to contain_exactly("patchwork", "newsmast", "leicester", "findout")
  end

  it "validates presence of :settings" do
    validators = described_class.validators_on(:settings)
    expect(validators.map(&:class)).to include(ActiveRecord::Validations::PresenceValidator)
  end

  it "validates presence of :account" do
    validators = described_class.validators_on(:account)
    expect(validators.map(&:class)).to include(ActiveRecord::Validations::PresenceValidator)
  end
end
