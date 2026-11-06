# Configuration

The gem is configured through environment variables on the Mastodon host (web and Sidekiq). The complete variable list with required/optional flags is in [configuration/environment-variables.md](../configuration/environment-variables.md). This page groups them by feature.

| Feature | Variables | Details |
| --- | --- | --- |
| Deep links | `IOS_APP_ID`, `IOS_DEEPLINK_PATHS`, `ANDROID_PACKAGE_NAME`, `ANDROID_SHA256_CERT_FINGERPRINTS`, `IOS_APP_STORE_URL`, `ANDROID_APP_STORE_URL` | Serves `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json`; each returns 404 when its ID is unset. |
| Push notifications | `FIREBASE_PROJECT_ID`, `FIREBASE_KEY_FILE_NAME`, `NOTIFICATION_SENDER_NAME`, `SKIP_SIGNUP_PUSH_NOTI` | See [Accounts](features.md#accounts). |
| Cross-instance push | `CROSS_INSTANCE_PUSH_TARGET_URL`, `CROSS_INSTANCE_PUSH_SECRET` | See [Accounts](features.md#accounts). |
| Sign-up | `ALLOWED_SIGNUP_EMAIL_DOMAIN`, `AUTO_FOLLOW_ENABLED`, `AUTO_FOLLOW_ACCOUNTS`, `WELCOME_EMAIL_DISABLED`, `DEFAULT_EMAIL_NOTIFICATIONS_ENABLED` | See [Accounts](features.md#accounts). |
| Mail branding | `MAIL_SENDER_NAME`, `MAIL_LOGO_URL`, `PRIVACY_POLICY_URL`, `TERMS_AND_CONDITIONS_URL` | |
| Alt text AI | `ALT_TEXT_ENABLED`, `ALT_TEXT_URL`, `ALT_TEXT_SECRET`, `ALT_TEXT_USER_TOGGLE`, `SKIP_ALT_TEXT_USER_SETTING` | alttext.ai only. See [Posts](features.md#posts). |
| Channels and boosting | `LOCAL_DOMAIN`, `MAIN_CHANNEL`, `REBLOG_*`, `BOOST_POST_*`, `BOOST_BOT_ENABLED`, `BOOST_COMMUNITY_BOT_*`, `{USERNAME}_INSTANCE_URL`, `{USERNAME}_CLIENT_ID`, `{USERNAME}_CLIENT_SECRET` | See [Posts](features.md#posts) and [Custom feeds](features.md#custom-feeds). |
| For You timeline | `FOR_YOU_TIMELINE_ENABLED`, `FOR_YOU_TIMELINE_CHANNELS` | See [Custom feeds](features.md#custom-feeds). |
| Custom relays | `CUSTOM_RELAY_DOMAINS` | See [Custom feeds](features.md#custom-feeds). |
| Status reactions | `PATCHWORK_STATUS_REACTION_NAMES`, `PATCHWORK_STATUS_REACTION_EMOJI_LIMIT` | See [Posts](features.md#posts). |

## Dashboard-managed settings

These live in the database (written by the Newsmast Dashboard), not in the environment:

| Setting name (`server_settings.name`) | Effect |
| --- | --- |
| `Content filters`, `Spam filters` | Turn keyword banning on. See [Content filters](features.md#content-filters). |
| `Long posts` | Raises the post character limit (value in `optional_value`). |
| `Local only posts` | Reported to clients by `GET /api/v1/local_only_posts/getLocalOnlySetting`. |
| `Threads`, `Bluesky` | Exclude those federated domains from a user's feeds. |
| `Automatic Search Opt-out` | New users are created non-discoverable and non-indexable. |
