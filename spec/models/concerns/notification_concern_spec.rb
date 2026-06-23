# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe NewsmastMastodon::Concerns::NotificationConcern, type: :model do
  it "defines the expected class method browserable" do
    expect(described_class).to be_a(Module)
    expect(described_class.const_get(:ClassMethods)).to be_a(Module)
  end

  it ".direct_mentions_only is defined as a class method via ClassMethods" do
    class_methods = described_class.const_get(:ClassMethods)
    expect(class_methods.instance_methods(false)).to include(:browserable, :direct_mentions_only)
  end
end
