# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::Concerns::AccountsCreation do
  subject(:controller) do
    Class.new do
      include NewsmastMastodon::Concerns::AccountsCreation
    end.new
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("LOCAL_DOMAIN", nil).and_return("example.test")
  end

  describe "#signup_reason" do
    it "keeps a supplied nonblank reason" do
      expect(controller.send(:signup_reason, "Because I want to join")).to eq("Because I want to join")
    end

    it "uses the signup fallback for blank or missing reasons" do
      expect(controller.send(:signup_reason, "   ")).to eq("Signing up via example.test App")
      expect(controller.send(:signup_reason, nil)).to eq("Signing up via example.test App")
    end
  end
end
