# frozen_string_literal: true

require "rails_helper"

RSpec.describe NewsmastMastodon::CivicrmRoleCheckService, type: :service do
  subject(:service) { described_class.new("member@example.org") }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("CIVICRM_BASE_URL", nil).and_return("https://csidnet.civicrm.org")
    allow(ENV).to receive(:fetch).with("CIVICRM_AUTH_TOKEN", nil).and_return("my-token")
    allow(ENV).to receive(:fetch).with("CSID_ROLE_ASSIGNMENT_ENABLED", "false").and_return("true")
  end

  it "returns empty values without an API request when disabled" do
    allow(ENV).to receive(:fetch).with("CSID_ROLE_ASSIGNMENT_ENABLED", "false").and_return("false")
    expect(described_class).not_to receive(:get)

    expect(service.call.values).to be_empty
  end

  it "checks remotely when forced while disabled" do
    allow(ENV).to receive(:fetch).with("CSID_ROLE_ASSIGNMENT_ENABLED", "false").and_return("false")
    stub_api_responses(api_response(values: contact_values))

    result = described_class.new("member@example.org", force_remote: true).call

    expect(result.values).to eq(contact_values)
    expect(result.group_id).to eq(15)
  end

  it "returns group 15 when its response contains a contact" do
    stub_api_responses(api_response(values: contact_values))

    result = service.call

    expect(result.to_h).to eq(values: contact_values, group_id: 15, transient_error: false)
    expect(@requested_group_ids).to eq([ 15 ])
  end

  it "checks group 16 after group 15 returns no contacts" do
    stub_api_responses(api_response(values: []), api_response(values: contact_values))

    result = service.call

    expect(result.to_h).to eq(values: contact_values, group_id: 16, transient_error: false)
    expect(@requested_group_ids).to eq([ 15, 16 ])
  end

  it "returns no group when neither response contains a contact" do
    stub_api_responses(api_response(values: []), api_response(values: []), api_response(values: []))

    expect(service.call.values).to be_empty
    expect(@requested_group_ids).to eq([ 15, 16, 3 ])
  end

  it "returns the Fellows role first without checking groups" do
    stub_api_responses(fellows: api_response(values: fellows_values))

    result = service.call

    expect(result.to_h).to eq(values: fellows_values, group_id: :fellows, transient_error: false)
    expect(@requested_group_ids).to be_empty
    expect(@fellows_params.fetch("where")).to eq(
      [
        [ "OR", [ [ "contact_id_a", "=", 992 ], [ "contact_id_b", "=", 992 ] ] ],
        [ "OR", [
          [ "contact_id_a.email_primary.email", "=", "member@example.org" ],
          [ "contact_id_b.email_primary.email", "=", "member@example.org" ]
        ] ],
        [ "is_active", "=", true ]
      ]
    )
  end

  it "falls back to groups when the relationship is not with the Fellows contact" do
    other = fellows_values.map { |value| value.merge("contact_id_b" => 993) }
    renamed = fellows_values.map { |value| value.merge("contact_id_b.display_name" => "Alumni") }
    stub_api_responses(api_response(values: contact_values), fellows: api_response(values: other + renamed))

    expect(service.call.group_id).to eq(15)
  end

  it "marks a failed Fellows check as transient without checking groups" do
    failed_response = instance_double("HTTParty::Response", success?: false, code: 503, body: "unavailable")
    stub_api_responses(fellows: failed_response)

    result = service.call

    expect(result.transient_error).to be(true)
    expect(@requested_group_ids).to be_empty
  end

  it "returns empty values when the response omits the values key" do
    response = instance_double(
      "HTTParty::Response",
      success?: true,
      parsed_response: { "count" => 0, "countFetched" => 0 },
      body: ""
    )
    stub_api_responses(response, response, response, fellows: response)

    expect(service.call.values).to be_empty
  end

  it "marks API failures as transient so the worker can retry" do
    failed_response = instance_double("HTTParty::Response", success?: false, code: 503, body: "unavailable")
    stub_api_responses(failed_response)

    result = service.call

    expect(result.values).to be_empty
    expect(result.transient_error).to be(true)
    expect(@requested_group_ids).to eq([ 15 ])
  end

  def api_response(values:)
    instance_double(
      "HTTParty::Response",
      success?: true,
      parsed_response: { "values" => values, "count" => values.length, "countFetched" => values.length },
      body: ""
    )
  end

  def contact_values
    [
      {
        "id" => 180,
        "email.email" => "member@example.org",
        "user_groups" => [ "Newsletter sign-up", "Committee import" ],
        "user_group_ids" => [ 4, 10 ]
      }
    ]
  end

  def fellows_values
    [
      {
        "id" => 260,
        "relationship_type_id" => 19,
        "contact_id_a" => 160,
        "contact_id_a.display_name" => "Member Example",
        "contact_id_a.email_primary.email" => "member@example.org",
        "contact_id_b" => 992,
        "contact_id_b.display_name" => "Fellows",
        "contact_id_b.email_primary.email" => nil
      }
    ]
  end

  # Positional responses answer the group (Contact/get) requests in order;
  # the Fellows (Relationship/get) request gets `fellows`, empty by default.
  def stub_api_responses(*responses, fellows: api_response(values: []))
    @requested_group_ids = []
    allow(described_class).to receive(:get) do |url, options|
      params = JSON.parse(options.fetch(:query).fetch(:params))
      if url.end_with?("/Relationship/get")
        @fellows_params = params
        fellows
      else
        @requested_group_ids << params.fetch("where").last.last.first
        responses.shift
      end
    end
  end
end
