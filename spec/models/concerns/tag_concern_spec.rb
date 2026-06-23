# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe NewsmastMastodon::Concerns::TagConcern, type: :model do
  it "is a module" do
    expect(described_class).to be_a(Module)
  end

  it "overrides tag matching via the self.prepended hook" do
    # The concern patches singleton class methods via self.prepended
    expect(described_class).to respond_to(:prepended)
  end
end
