# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Consolidated engine routes", type: :routing do
  let(:routes)  { NewsmastMastodon::Engine.routes }
  let(:helpers) { routes.url_helpers }
  let(:named)   { routes.named_routes.helper_names }

  # Routes extracted to patchwork_extensions (Gem B) are no longer served by
  # this engine and are intentionally not asserted here: COMMUNITY-03 channels,
  # CONV-01 conversations, MEDIA-02 utilities/link_preview, AUTH-06
  # user_locales / account_deletion / delete_account, UI-03 .well-known,
  # FEED-02 for_you_custom_timeline, CMS-02 subscribe_leicester,
  # BOOST-01 custom_statuses/*.
  it "routes accounts: custom_passwords, notification_tokens, patchwork/*" do
    expect(named).to include("api_v1_custom_passwords_path", "verify_otp_api_v1_custom_passwords_path", "request_otp_api_v1_custom_passwords_path")
    expect(named).to include("api_v1_notification_tokens_path", "revoke_token_api_v1_notification_tokens_path", "update_mute_api_v1_notification_tokens_path")
    expect(named).to include("alttext_api_v1_patchwork_alttext_settings_path", "notification_api_v1_patchwork_email_settings_path")
    expect(named).to include("api_v1_accounts_leicester_notification_path")

    expect(helpers.api_v1_custom_passwords_path).to eq("/api/v1/custom_passwords")
    expect(helpers.verify_otp_api_v1_custom_passwords_path).to eq("/api/v1/custom_passwords/verify_otp")
    expect(helpers.request_otp_api_v1_custom_passwords_path).to eq("/api/v1/custom_passwords/request_otp")

    expect(helpers.api_v1_notification_tokens_path).to eq("/api/v1/notification_tokens")
    expect(helpers.revoke_token_api_v1_notification_tokens_path).to eq("/api/v1/notification_tokens/revoke_token")
    expect(helpers.update_mute_api_v1_notification_tokens_path).to eq("/api/v1/notification_tokens/update_mute")

    expect(helpers.alttext_api_v1_patchwork_alttext_settings_path).to eq("/api/v1/patchwork/alttext_settings/alttext")
    expect(helpers.notification_api_v1_patchwork_email_settings_path).to eq("/api/v1/patchwork/email_settings/notification")
    expect(helpers.api_v1_accounts_leicester_notification_path).to eq("/api/v1/accounts/leicester_notification")
  end

  it "routes custom_feeds: timelines/@user/feed" do
    expect(named).to include("api_v1_timelines_custom_feed_path")

    expect(helpers.api_v1_timelines_custom_feed_path(username: "alice")).to eq("/api/v1/timelines/@alice/feed")
  end

  it "routes local_only_posts: getLocalOnlySetting" do
    expect(named).to include("getLocalOnlySetting_api_v1_local_only_posts_path")
    expect(helpers.getLocalOnlySetting_api_v1_local_only_posts_path).to eq("/api/v1/local_only_posts/getLocalOnlySetting")
  end

  it "routes posts: drafted_statuses/*, relays, ghost_webhooks, wordpress_webhooks" do
    expect(named).to include("api_v1_drafted_statuses_path", "api_v1_drafted_status_path", "publish_api_v1_drafted_status_path")
    expect(named).to include("api_v1_patchwork_relays_path")
    expect(named).to include("api_v1_ghost_webhooks_path", "api_v1_wordpress_webhooks_path")

    expect(helpers.api_v1_drafted_statuses_path).to eq("/api/v1/drafted_statuses")
    expect(helpers.api_v1_drafted_status_path(1)).to eq("/api/v1/drafted_statuses/1")
    expect(helpers.publish_api_v1_drafted_status_path(1)).to eq("/api/v1/drafted_statuses/1/publish")

    expect(helpers.api_v1_patchwork_relays_path).to eq("/api/v1/patchwork/relays")

    expect(helpers.api_v1_ghost_webhooks_path).to eq("/api/v1/ghost_webhooks")
    expect(helpers.api_v1_wordpress_webhooks_path).to eq("/api/v1/wordpress_webhooks")
  end
end
