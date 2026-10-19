# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::ServerSetting, type: :model do
  it "validates presence of :name" do
    setting = NewsmastMastodon::ServerSetting.new(name: nil)
    expect(setting).not_to be_valid
    expect(setting.errors[:name]).not_to be_empty
  end

  it "allows nil :optional_value" do
    setting = NewsmastMastodon::ServerSetting.new(name: "test_setting")
    expect(setting).to be_valid
  end

  it "belongs_to :parent and has_many :children" do
    parent_ref   = NewsmastMastodon::ServerSetting.reflect_on_association(:parent)
    children_ref = NewsmastMastodon::ServerSetting.reflect_on_association(:children)
    expect(parent_ref).not_to be_nil
    expect(parent_ref.macro).to eq(:belongs_to)
    expect(children_ref).not_to be_nil
    expect(children_ref.macro).to eq(:has_many)
  end

  it "has_many :user_server_settings" do
    ref = NewsmastMastodon::ServerSetting.reflect_on_association(:user_server_settings)
    expect(ref).not_to be_nil
    expect(ref.macro).to eq(:has_many)
  end

  it ".get_long_post(name) returns the expected setting value" do
    setting = NewsmastMastodon::ServerSetting.create!(name: "long_post_limit")
    expect(NewsmastMastodon::ServerSetting.get_long_post("long_post_limit")).to eq(setting)
  end

  it ".get_long_post finds the dashboard setting by key when its name differs" do
    setting = described_class.create!(key: "long_posts", name: "long_posts", value: true, optional_value: "3000")

    expect(described_class.get_long_post("Long posts")).to eq(setting)
  end

  it ".get_long_post prefers the keyed setting over a legacy display name" do
    described_class.create!(name: "Long posts", value: false)
    setting = described_class.create!(key: "long_posts", name: "Longer posts", value: true, optional_value: "3000")

    expect(described_class.get_long_post("Long posts")).to eq(setting)
  end
end
