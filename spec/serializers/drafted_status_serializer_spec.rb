# frozen_string_literal: true

require "rails_helper"

RSpec.describe LongPost::DraftedStatusSerializer, type: :serializer do
  let(:draft) do
    NewsmastMastodon::DraftedStatus.create!(
      account: Fabricate(:account),
      params: { "text" => "Draft text", "visibility" => "public", "application_id" => 42 }
    ).reload
  end

  let(:json) { ActiveModelSerializers::SerializableResource.new(draft, serializer: described_class).as_json }

  it "serializes :id as a string" do
    require_host!

    expect(json[:id]).to eq(draft.id.to_s)
  end

  it "serializes :params without :application_id" do
    require_host!

    expect(json[:params]).to include("text" => "Draft text", "visibility" => "public")
    expect(json[:params].keys.map(&:to_s)).not_to include("application_id")
  end

  it "serializes :media_attachments" do
    require_host!

    # A remote attachment avoids needing an uploaded file in this spec.
    attachment = MediaAttachment.create!(account: draft.account, type: :image, remote_url: "https://example.com/image.png")
    attachment.update_column(:patchwork_drafted_status_id, draft.id)

    expect(json[:media_attachments].map { |media| media[:id] }).to eq([ attachment.id.to_s ])
  end
end
