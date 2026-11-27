# frozen_string_literal: true

#
# Every example is `skip`ped until the Mastodon host harness is available.
# Remove the `skip` and implement the expectation once the host is loaded.
require "rails_helper"

RSpec.describe "Concern prepends", type: :integration do
  it "Status ancestors include NewsmastMastodon::Concerns::StatusConcern" do
    require_host!
    expect(Status.ancestors).to include(NewsmastMastodon::Concerns::StatusConcern)
  end

  it "Account ancestors include NewsmastMastodon::Concerns::AccountConcern" do
    require_host!
    expect(Account.ancestors).to include(NewsmastMastodon::Concerns::AccountConcern)
  end

  it "Feed ancestors include NewsmastMastodon::Concerns::FeedConcern" do
    require_host!
    expect(Feed.ancestors).to include(NewsmastMastodon::Concerns::FeedConcern)
  end

  it "User ancestors include NewsmastMastodon::Concerns::UserConcern" do
    require_host!
    expect(User.ancestors).to include(NewsmastMastodon::Concerns::UserConcern)
  end

  it "all controller prepends resolve to NewsmastMastodon::Overrides::*" do
    require_host!
    expect(Api::V1::StatusesController.ancestors).to include(NewsmastMastodon::Api::V1::StatusesControllerExtension)
    expect(Api::V1::Timelines::HomeController.ancestors).to include(NewsmastMastodon::Overrides::HomeExtendedTimeline)
    expect(Api::V1::Timelines::PublicController.ancestors).to include(NewsmastMastodon::Overrides::PublicExtendedTimeline)
    expect(FanOutOnWriteService.ancestors).to include(NewsmastMastodon::Concerns::FanOutOnWriteConcern)
  end

  # `bin/rails newsmast_mastodon:install` copies the engine's Chewy indexes
  # into the host's app/chewy, renamed to the upstream top-level classes.
  let(:chewy_index_files) do
    {
      "AccountsIndex" => "accounts_index.rb",
      "StatusesIndex" => "statuses_index.rb",
      "PublicStatusesIndex" => "public_statuses_index.rb"
    }
  end

  it "loads the host Chewy index classes from the files installed by the engine" do
    require_host!

    chewy_index_files.each do |class_name, file|
      installed = Rails.root.join("app/chewy", file)
      engine_source = File.read(NewsmastMastodon::Engine.root.join("app/chewy/newsmast_mastodon", file))
      expected = engine_source.gsub(/class\s+NewsmastMastodon::(\w+Index)\s+</, 'class \\1 <')

      expect(File.read(installed)).to eq(expected), "#{installed} is not the installed engine index; run newsmast_mastodon:install"
      index_class = Object.const_get(class_name)
      expect(index_class).to be < Chewy::Index
      expect(Object.const_source_location(class_name).first).to eq(installed.to_s)
    end
  end

  it "keeps the upstream Chewy index names so existing indexes are reused" do
    require_host!

    expect(AccountsIndex.base_name).to eq("accounts")
    expect(StatusesIndex.base_name).to eq("statuses")
    expect(PublicStatusesIndex.base_name).to eq("public_statuses")
  end
end
