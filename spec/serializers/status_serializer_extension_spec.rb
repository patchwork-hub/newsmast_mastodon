# frozen_string_literal: true

require "rails_helper"

RSpec.describe LocalOnlyPosts::StatusSerializerExtension, type: :serializer do
  let(:status) { Fabricate(:status, local_only: true) }

  def serialize(status, **options)
    ActiveModelSerializers::SerializableResource.new(
      status, serializer: REST::StatusSerializer, scope: nil, scope_name: :current_user, **options
    ).as_json
  end

  it "includes :local_only field in status JSON" do
    require_host!

    expect(serialize(status)[:local_only]).to be(true)
  end

  it "omits :patchwork_post_reactions unless requested" do
    require_host!

    expect(serialize(status)).not_to have_key(:patchwork_post_reactions)
  end

  it "includes :patchwork_post_reactions when requested" do
    require_host!

    reactions = { status.id => [ { name: "heart", count: 2 } ] }
    json = serialize(status, include_patchwork_post_reactions: true, patchwork_post_reactions: reactions)

    expect(json[:patchwork_post_reactions]).to eq([ { name: "heart", count: 2 } ])
  end
end
