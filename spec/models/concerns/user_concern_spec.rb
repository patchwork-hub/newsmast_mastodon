# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe NewsmastMastodon::Concerns::UserConcern, type: :model do
  it "is a module" do
    expect(described_class).to be_a(Module)
  end

  it "defines get_server_setting_exclude_domains instance method" do
    expect(described_class.instance_methods(false)).to include(:get_server_setting_exclude_domains)
  end

  it "#get_server_setting_exclude_domains returns Threads domains when setting enabled" do
    obj = Object.new
    obj.extend(described_class)
    server_setting_class = Class.new do
      def self.where(*); end
    end
    stub_const("NewsmastMastodon::ServerSetting", server_setting_class)

    threads_setting = double("NewsmastMastodon::ServerSetting", value?: true)
    bluesky_setting = double("NewsmastMastodon::ServerSetting", value?: false)

    allow(NewsmastMastodon::ServerSetting).to receive(:where).with(name: "Threads").and_return(double(first: threads_setting))
    allow(NewsmastMastodon::ServerSetting).to receive(:where).with(name: "Bluesky").and_return(double(first: bluesky_setting))

    result = obj.get_server_setting_exclude_domains
    expect(result).to include("threads.social", "threads.net")
    expect(result).not_to include("bridgy.fed")
  end

  it "#get_server_setting_exclude_domains returns Bluesky domains when setting enabled" do
    obj = Object.new
    obj.extend(described_class)
    server_setting_class = Class.new do
      def self.where(*); end
    end
    stub_const("NewsmastMastodon::ServerSetting", server_setting_class)

    threads_setting = double("NewsmastMastodon::ServerSetting", value?: false)
    bluesky_setting = double("NewsmastMastodon::ServerSetting", value?: true)

    allow(NewsmastMastodon::ServerSetting).to receive(:where).with(name: "Threads").and_return(double(first: threads_setting))
    allow(NewsmastMastodon::ServerSetting).to receive(:where).with(name: "Bluesky").and_return(double(first: bluesky_setting))

    result = obj.get_server_setting_exclude_domains
    expect(result).to include("bridgy.fed", "bluesky.social")
    expect(result).not_to include("threads.social")
  end

  it "has DOMAIN_FILTERS constant with Threads and Bluesky keys" do
    expect(NewsmastMastodon::Concerns::UserConcern::DOMAIN_FILTERS).to have_key(:Threads)
    expect(NewsmastMastodon::Concerns::UserConcern::DOMAIN_FILTERS).to have_key(:Bluesky)
  end

  it "accepts signup email when domain is allowed" do
    obj = Object.new
    obj.extend(described_class)
    obj.define_singleton_method(:email) { "user@allowed.org" }

    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ALLOWED_SIGNUP_EMAIL_DOMAIN").and_return("allowed.org, another.org")

    errors = instance_double("Errors")
    obj.define_singleton_method(:errors) { errors }
    expect(errors).not_to receive(:add)

    obj.send(:validate_email_domain)
  end

  it "rejects signup email when domain is not allowed" do
    obj = Object.new
    obj.extend(described_class)
    obj.define_singleton_method(:email) { "user@blocked.org" }

    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ALLOWED_SIGNUP_EMAIL_DOMAIN").and_return("allowed.org, another.org")

    errors = instance_double("Errors")
    obj.define_singleton_method(:errors) { errors }
    expect(errors).to receive(:add).with(:email, "must be from an allowed domain: allowed.org, another.org")

    obj.send(:validate_email_domain)
  end
end
