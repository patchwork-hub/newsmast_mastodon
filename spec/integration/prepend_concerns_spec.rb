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
end
