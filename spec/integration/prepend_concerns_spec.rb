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

  it "replaces host Chewy index classes with the engine's definitions" do
    require_host!
    expect(AccountsIndex).to be(NewsmastMastodon::AccountsIndex)
    expect(StatusesIndex).to be(NewsmastMastodon::StatusesIndex)
    expect(PublicStatusesIndex).to be(NewsmastMastodon::PublicStatusesIndex)
  end

  it "preserves upstream Chewy index names when the engine overrides the class" do
    require_host!
    expect(NewsmastMastodon::AccountsIndex.index_name).to eq("accounts_index")
    expect(NewsmastMastodon::StatusesIndex.index_name).to eq("statuses_index")
    expect(NewsmastMastodon::PublicStatusesIndex.index_name).to eq("public_statuses_index")
  end
end
