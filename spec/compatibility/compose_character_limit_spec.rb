# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Compose character limit compatibility" do
  it "reads the instance configuration from the server reducer item" do
    source = File.read(File.expand_path("../../app/javascript/newsmast_mastodon/mastodon/features/compose/containers/compose_form_container.js", __dir__))

    expect(source).to include("maxChars: state.getIn(['server', 'server', 'item', 'configuration', 'statuses', 'max_characters'], 500)")
  end
end
