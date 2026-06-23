# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe NewsmastMastodon::Concerns::AccountConcern, type: :model do
  let(:host_class) do
    klass = Class.new do
      class << self
        def has_many(*args, **kwargs, &block); end
        def scope(*args, &block); end
        def included_modules; []; end
      end

      attr_accessor :id
    end
    klass.include(described_class)
    klass
  end

  it "is a module" do
    expect(described_class).to be_a(Module)
  end

  it "is an ActiveSupport::Concern" do
    expect(described_class).to respond_to(:included)
  end

  it "#follow_account? delegates to Follow.exists?" do
    stub_const("Follow", Class.new { def self.exists?(*); false; end })
    instance = host_class.new
    instance.id = 42
    allow(Follow).to receive(:exists?).with(account_id: 42, target_account_id: 99).and_return(true)

    expect(instance.follow_account?(99)).to be true
  end

  it "#follow_account? returns false when no follow exists" do
    stub_const("Follow", Class.new { def self.exists?(*); false; end })
    instance = host_class.new
    instance.id = 42
    allow(Follow).to receive(:exists?).with(account_id: 42, target_account_id: 99).and_return(false)

    expect(instance.follow_account?(99)).to be false
  end
end
