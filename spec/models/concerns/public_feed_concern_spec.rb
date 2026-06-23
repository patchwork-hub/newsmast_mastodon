# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe NewsmastMastodon::Concerns::PublicFeedConcern, type: :model do
  it "is a module" do
    expect(described_class).to be_a(Module)
  end

  it "defines private feed helper methods" do
    private_methods = described_class.private_instance_methods(false)
    expect(private_methods).to include(:with_reblogs?, :with_replies?, :apply_filters)
  end

  it "#get returns empty array when incompatible_feed_settings? is true" do
    # Build minimal host that includes the concern's included block
    klass = Class.new do
      class << self
        def included_modules; []; end
        def include(*); end
      end
    end

    obj = Object.new
    obj.extend(described_class)
    obj.instance_variable_set(:@account, nil)
    obj.instance_variable_set(:@options, {})
    obj.define_singleton_method(:incompatible_feed_settings?) { true }

    result = obj.get(20)
    expect(result).to eq([])
  end
end
