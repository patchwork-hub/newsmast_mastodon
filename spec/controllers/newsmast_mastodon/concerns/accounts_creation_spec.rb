# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::Concerns::AccountsCreation do
  subject(:controller) do
    Class.new do
      include NewsmastMastodon::Concerns::AccountsCreation
    end.new
  end

  before do
    allow(NewsmastMastodon::CivicrmRoleAssignmentWorker).to receive(:perform_async)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("CSID_ROLE_ASSIGNMENT_ENABLED", "false").and_return("true")
  end

  it "enqueues role assignment for the newly created user" do
    token = instance_double("Doorkeeper::AccessToken", resource_owner_id: 42)

    controller.send(:enqueue_role_assignment, token)

    expect(NewsmastMastodon::CivicrmRoleAssignmentWorker).to have_received(:perform_async).with(42)
  end

  it "does not enqueue when role assignment is disabled" do
    allow(ENV).to receive(:fetch).with("CSID_ROLE_ASSIGNMENT_ENABLED", "false").and_return("false")
    token = instance_double("Doorkeeper::AccessToken", resource_owner_id: 42)

    controller.send(:enqueue_role_assignment, token)

    expect(NewsmastMastodon::CivicrmRoleAssignmentWorker).not_to have_received(:perform_async)
  end

  it "does not enqueue without a resource owner" do
    token = instance_double("Doorkeeper::AccessToken", resource_owner_id: nil)

    controller.send(:enqueue_role_assignment, token)

    expect(NewsmastMastodon::CivicrmRoleAssignmentWorker).not_to have_received(:perform_async)
  end
end
