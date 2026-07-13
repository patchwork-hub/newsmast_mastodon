# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Consolidated engine routes", type: :routing do
  let(:routes)  { NewsmastMastodon::Engine.routes }
  let(:helpers) { routes.url_helpers }
  let(:named)   { routes.named_routes.helper_names }
  let(:account_deletion_helper) { named.find { |name| name.match?(/account_deletion.*_path\z/) } }

  it "routes accounts: custom_passwords, notification_tokens, user_locales, channels, patchwork/*" do
    expect(named).to include("api_v1_custom_passwords_path", "verify_otp_api_v1_custom_passwords_path", "request_otp_api_v1_custom_passwords_path")
    expect(named).to include("api_v1_notification_tokens_path", "revoke_token_api_v1_notification_tokens_path", "update_mute_api_v1_notification_tokens_path")
    expect(named).to include("api_v1_user_locales_path", "starter_packs_channels_api_v1_channels_path", "starter_packs_detail_api_v1_channel_path")
    expect(named).to include("alttext_api_v1_patchwork_alttext_settings_path", "notification_api_v1_patchwork_email_settings_path")
    expect(account_deletion_helper).not_to be_nil
    expect(named).to include("api_v1_accounts_leicester_notification_path", "api_v1_accounts_subscribe_leicester_path")

    expect(helpers.api_v1_custom_passwords_path).to eq("/api/v1/custom_passwords")
    expect(helpers.verify_otp_api_v1_custom_passwords_path).to eq("/api/v1/custom_passwords/verify_otp")
    expect(helpers.request_otp_api_v1_custom_passwords_path).to eq("/api/v1/custom_passwords/request_otp")

    expect(helpers.api_v1_notification_tokens_path).to eq("/api/v1/notification_tokens")
    expect(helpers.revoke_token_api_v1_notification_tokens_path).to eq("/api/v1/notification_tokens/revoke_token")
    expect(helpers.update_mute_api_v1_notification_tokens_path).to eq("/api/v1/notification_tokens/update_mute")

    expect(helpers.api_v1_user_locales_path).to eq("/api/v1/user_locales")
    expect(helpers.starter_packs_channels_api_v1_channels_path).to eq("/api/v1/channels/starter_packs_channels")
    expect(helpers.starter_packs_detail_api_v1_channel_path(1)).to eq("/api/v1/channels/1/starter_packs_detail")
    expect(helpers.search_local_accounts_api_v1_channel_path(1)).to eq("/api/v1/channels/1/search_local_accounts")
    expect(helpers.assigned_roles_api_v1_channel_path(1)).to eq("/api/v1/channels/1/assigned_roles")
    expect(helpers.assign_role_api_v1_channel_path(1)).to eq("/api/v1/channels/1/assign_role")
    expect(helpers.remove_assigned_role_api_v1_channel_path(1)).to eq("/api/v1/channels/1/remove_assigned_role")
    expect(helpers.invite_user_api_v1_channel_path(1)).to eq("/api/v1/channels/1/invite_user")

    expect(helpers.alttext_api_v1_patchwork_alttext_settings_path).to eq("/api/v1/patchwork/alttext_settings/alttext")
    expect(helpers.notification_api_v1_patchwork_email_settings_path).to eq("/api/v1/patchwork/email_settings/notification")
    expect(helpers.public_send(account_deletion_helper, 1)).to eq("/api/v1/patchwork/account_deletion/1")
    expect(helpers.api_v1_accounts_leicester_notification_path).to eq("/api/v1/accounts/leicester_notification")
    expect(helpers.api_v1_accounts_subscribe_leicester_path).to eq("/api/v1/accounts/subscribe_leicester")
  end

  it "routes conversations: /api/v1/patchwork/conversations/*" do
    expect(named).to include("check_conversation_api_v1_patchwork_conversations_path", "read_all_api_v1_patchwork_conversations_path")
    expect(helpers.check_conversation_api_v1_patchwork_conversations_path).to eq("/api/v1/patchwork/conversations/check_conversation")
    expect(helpers.read_all_api_v1_patchwork_conversations_path).to eq("/api/v1/patchwork/conversations/read_all")
  end

  it "routes custom_feeds: timelines/@user/feed, for_you_custom_timeline, custom_statuses/*" do
    expect(named).to include("api_v1_timelines_custom_feed_path", "api_v1_timelines_for_you_custom_timeline_path")
    expect(named).to include("api_v1_custom_statuses_add_custom_boost_bot_status_path", "api_v1_custom_statuses_remove_custom_boost_bot_status_path")

    expect(helpers.api_v1_timelines_custom_feed_path(username: "alice")).to eq("/api/v1/timelines/@alice/feed")
    expect(helpers.api_v1_timelines_for_you_custom_timeline_path).to eq("/api/v1/timelines/for_you_custom_timeline")
    expect(helpers.api_v1_custom_statuses_add_custom_boost_bot_status_path).to eq("/api/v1/custom_statuses/add_custom_boost_bot_status")
    expect(helpers.api_v1_custom_statuses_remove_custom_boost_bot_status_path).to eq("/api/v1/custom_statuses/remove_custom_boost_bot_status")
  end

  it "routes local_only_posts: getLocalOnlySetting" do
    expect(named).to include("getLocalOnlySetting_api_v1_local_only_posts_path")
    expect(helpers.getLocalOnlySetting_api_v1_local_only_posts_path).to eq("/api/v1/local_only_posts/getLocalOnlySetting")
  end

  it "routes posts: drafted_statuses/*, utilities/link_preview, relays, ghost_webhooks, wordpress_webhooks" do
    expect(named).to include("api_v1_drafted_statuses_path", "api_v1_drafted_status_path", "publish_api_v1_drafted_status_path")
    expect(named).to include("link_preview_api_v1_utilities_path", "api_v1_patchwork_relays_path")
    expect(named).to include("api_v1_ghost_webhooks_path", "api_v1_wordpress_webhooks_path")

    expect(helpers.api_v1_drafted_statuses_path).to eq("/api/v1/drafted_statuses")
    expect(helpers.api_v1_drafted_status_path(1)).to eq("/api/v1/drafted_statuses/1")
    expect(helpers.publish_api_v1_drafted_status_path(1)).to eq("/api/v1/drafted_statuses/1/publish")

    expect(helpers.link_preview_api_v1_utilities_path).to eq("/api/v1/utilities/link_preview")
    expect(helpers.api_v1_patchwork_relays_path).to eq("/api/v1/patchwork/relays")

    expect(helpers.api_v1_ghost_webhooks_path).to eq("/api/v1/ghost_webhooks")
    expect(helpers.api_v1_wordpress_webhooks_path).to eq("/api/v1/wordpress_webhooks")
  end
end
