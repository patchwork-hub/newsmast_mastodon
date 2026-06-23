# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe NewsmastMastodon::Concerns::StatusConcern, type: :model do
  it "is a module" do
    expect(described_class).to be_a(Module)
  end

  it "defines private callback helpers as instance methods" do
    private_methods = described_class.private_instance_methods(false)
    expect(private_methods).to include(:set_locality, :boost_posts_enabled?, :for_you_timeline_enabled?)
  end

  it "defines search_word_in_status instance method" do
    # search_word_in_status is defined in included but with def, so becomes instance method
    # Verify via the concern's public instance methods
    expect(described_class.instance_methods(false)).to include(:search_word_in_status)
  end

  it "#search_word_in_status matches a keyword in plain text" do
    obj = Object.new
    obj.instance_variable_set(:@text, "This post mentions patchwork in context")
    obj.define_singleton_method(:text) { @text }
    obj.extend(described_class)

    expect(obj.search_word_in_status("patchwork")).to be true
  end

  it "#search_word_in_status returns false when keyword absent" do
    obj = Object.new
    obj.instance_variable_set(:@text, "No keywords here")
    obj.define_singleton_method(:text) { @text }
    obj.extend(described_class)

    expect(obj.search_word_in_status("missing")).to be false
  end

  it "#boost_posts_enabled? is false when env var unset" do
    obj = Object.new
    obj.extend(described_class)
    allow(ENV).to receive(:present?).and_call_original
    stub_const("ENV", ENV.to_hash.except("BOOST_POST_ENABLED"))
    expect(obj.send(:boost_posts_enabled?)).to be false
  end
end
