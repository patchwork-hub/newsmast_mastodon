# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::AutoFollowDefaultAccountsService, type: :service do
  it "uses enabled ENV configuration when the dashboard table is missing" do
    source_account = instance_double("Account", local?: true, acct: "source")
    target_one = instance_double("Account", acct: "one")
    target_two = instance_double("Account", acct: "two")
    allow(ActiveRecord::Base.connection).to receive(:data_source_exists?).and_return(false)

    resolve_service = instance_double("ResolveAccountService")
    resolve_service_class = class_double("ResolveAccountService", new: resolve_service)
    stub_const("ResolveAccountService", resolve_service_class)

    allow(resolve_service).to receive(:call).with("@one@example.org").and_return(target_one)
    allow(resolve_service).to receive(:call).with("@two@example.org").and_return(nil)
    allow(resolve_service).to receive(:call).with("@two@example.org", skip_webfinger: true).and_return(target_two)

    follow_service = instance_double("FollowService", call: true)
    follow_service_class = class_double("FollowService", new: follow_service)
    stub_const("FollowService", follow_service_class)

    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("AUTO_FOLLOW_ENABLED").and_return("true")
    allow(ENV).to receive(:[]).with("AUTO_FOLLOW_ACCOUNTS").and_return("@one@example.org,@two@example.org")

    described_class.new.call(source_account)

    expect(follow_service).to have_received(:call).with(source_account, target_one, bypass_locked: true, bypass_limit: true)
    expect(follow_service).to have_received(:call).with(source_account, target_two, bypass_locked: true, bypass_limit: true)
  end

  it "follows ordered database accounts when an enabled instance list exists" do
    source_account = instance_double("Account", local?: true, acct: "source")
    first_account = instance_double("Account", acct: "first")
    second_account = instance_double("Account", acct: "second")
    memberships = [double(account: first_account), double(account: second_account)]
    auto_follow = double(instance_name: "tootwales", enabled?: true, auto_follow_accounts: memberships)
    allow_any_instance_of(described_class).to receive(:dashboard_auto_follow).and_return(auto_follow)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("AUTO_FOLLOW_ENABLED").and_return("false")
    follow_service = instance_double("FollowService", call: true)
    follow_service_class = class_double("FollowService", new: follow_service)
    stub_const("FollowService", follow_service_class)

    described_class.new.call(source_account)

    expect(follow_service).to have_received(:call).with(source_account, first_account, bypass_locked: true, bypass_limit: true).ordered
    expect(follow_service).to have_received(:call).with(source_account, second_account, bypass_locked: true, bypass_limit: true).ordered
  end

  it "does not use ENV when the matching database list is disabled" do
    source_account = instance_double("Account", local?: true, acct: "source")
    auto_follow = double(instance_name: "tootwales", enabled?: false)
    allow_any_instance_of(described_class).to receive(:dashboard_auto_follow).and_return(auto_follow)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("AUTO_FOLLOW_ENABLED").and_return("true")
    follow_service = instance_double("FollowService", call: true)
    follow_service_class = class_double("FollowService", new: follow_service)
    stub_const("FollowService", follow_service_class)

    described_class.new.call(source_account)

    expect(follow_service).not_to have_received(:call)
  end

  it "falls back to ENV when there is no matching instance list" do
    source_account = instance_double("Account", local?: true, acct: "source")
    allow_any_instance_of(described_class).to receive(:dashboard_auto_follow).and_return(nil)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("AUTO_FOLLOW_ENABLED").and_return("true")
    allow(ENV).to receive(:[]).with("AUTO_FOLLOW_ACCOUNTS").and_return("@fallback@example.org")
    target = instance_double("Account", acct: "fallback")
    resolver = instance_double("ResolveAccountService", call: target)
    resolve_service_class = class_double("ResolveAccountService", new: resolver)
    stub_const("ResolveAccountService", resolve_service_class)
    follow_service = instance_double("FollowService", call: true)
    follow_service_class = class_double("FollowService", new: follow_service)
    stub_const("FollowService", follow_service_class)

    described_class.new.call(source_account)

    expect(follow_service).to have_received(:call).with(source_account, target, bypass_locked: true, bypass_limit: true)
  end

  it "logs and skips ENV targets that cannot be resolved" do
    source_account = instance_double("Account", local?: true, acct: "source")
    allow(ActiveRecord::Base.connection).to receive(:data_source_exists?).and_return(false)
    resolver = instance_double("ResolveAccountService", call: nil)
    resolve_service_class = class_double("ResolveAccountService", new: resolver)
    stub_const("ResolveAccountService", resolve_service_class)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("AUTO_FOLLOW_ENABLED").and_return("true")
    allow(ENV).to receive(:[]).with("AUTO_FOLLOW_ACCOUNTS").and_return("@missing@example.org")
    expect(Rails.logger).to receive(:warn).with("Auto-follow target @missing@example.org could not be resolved for source")

    described_class.new.call(source_account)
  end

  it "selects only a list matching the current instance" do
    exact_match = double(instance_name: "tootwales")
    other_instance = double(instance_name: "another")
    service = described_class.new
    allow(ENV).to receive(:fetch).with("LOCAL_DOMAIN", "").and_return("toot.wales")

    expect(service.send(:select_dashboard_auto_follow, [other_instance, exact_match])).to eq(exact_match)
    expect(service.send(:select_dashboard_auto_follow, [other_instance])).to be_nil
    expect(service.send(:select_dashboard_auto_follow, [other_instance, double(instance_name: "third")])).to be_nil
  end
end
