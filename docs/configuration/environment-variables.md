# Environment Variables

This page lists runtime environment variables supported by newsmast_mastodon.

## Deep linking

| Variable | Required | Description |
| --- | --- | --- |
| IOS_APP_ID | Yes (for iOS) | Full iOS app identifier in TeamID.BundleID format (for example: ABCDE12345.com.example.app). AASA returns 404 if not set. |
| IOS_DEEPLINK_PATHS | No | Comma-separated URL path patterns (defaults to /@*,/@*/*). |
| ANDROID_PACKAGE_NAME | Yes (for Android) | Android app package name (for example: com.example.app). Asset links returns 404 if not set. |
| ANDROID_SHA256_CERT_FINGERPRINTS | Yes (for Android) | Comma-separated SHA-256 certificate fingerprints for Android app verification. Asset links returns 404 if not set. |
| IOS_APP_STORE_URL | No | iOS App Store link for email footers. |
| ANDROID_APP_STORE_URL | No | Google Play Store link for email footers. |

## Firebase notifications

| Variable | Required | Description |
| --- | --- | --- |
| FIREBASE_PROJECT_ID | No | Firebase project ID for push notifications. |
| FIREBASE_KEY_FILE_NAME | No | Path to Firebase service account key JSON file. |

## Reblog and boost services

| Variable | Required | Description |
| --- | --- | --- |
| REBLOG_ENABLED | No | Enable reblog functionality (set to true to enable). |
| REBLOG_INSTANCE_URL | No | Mastodon instance URL for reblog operations. |
| REBLOG_EMAIL | No | Email account for reblog authentication. |
| REBLOG_PASSWORD | No | Password for reblog authentication. |
| REBLOG_CLIENT_ID | Yes (if reblog enabled) | OAuth client ID for reblog instance. |
| REBLOG_CLIENT_SECRET | Yes (if reblog enabled) | OAuth client secret for reblog instance. |
| BOOST_POST_ENABLED | No | Enable/disable automatic post boosting (`true`/`false`). |
| BOOST_POST_INSTANCE_URL | No | Boost instance URL for post boosting. |
| BOOST_POST_API_KEY | No | API key for Boost post service. |
| BOOST_POST_API_SECRET | No | API secret for Boost post service. |
| BOOST_POST_USERNAME | No | Username for Boost account. |
| BOOST_POST_USER_DOMAIN | No | Domain for Boost account user. |
| BOOST_BOT_ENABLED | No | Enable/disable automated community boost bot behavior. |
| BOOST_COMMUNITY_BOT_URL | No | Boost community bot instance URL. |
| BOOST_COMMUNITY_BOT_API_KEY | No | API key for Boost community bot. |

## Custom boost bot

| Variable | Required | Description |
| --- | --- | --- |
| {USERNAME}_INSTANCE_URL | No | Mastodon instance URL for custom boost bot (replace {USERNAME} with bot username in uppercase). |
| {USERNAME}_CLIENT_ID | No | OAuth client ID for custom boost bot instance. |
| {USERNAME}_CLIENT_SECRET | No | OAuth client secret for custom boost bot instance. |

## Mail and branding

| Variable | Required | Description |
| --- | --- | --- |
| MAIL_SENDER_NAME | No | Sender name for email notifications (default: Development Patchwork). |
| MAIL_LOGO_URL | No | Logo URL for email headers. Defaults to Patchwork demo asset URL if not set. |
| PRIVACY_POLICY_URL | No | Privacy policy URL for email footers. |
| TERMS_AND_CONDITIONS_URL | No | Terms of service URL for email footers. |

## Notification services

| Variable | Required | Description |
| --- | --- | --- |
| NOTIFICATION_SENDER_NAME | No | Sender name for push notifications (default: Development Patchwork). |
| SKIP_SIGNUP_PUSH_NOTI | No | Skip sending push notifications on signup (set to true to skip). |
| DEFAULT_EMAIL_NOTIFICATIONS_ENABLED | No | Default email notification state for newly created users (`true`/`false`). |

## Alt text AI

The automatic alt text feature currently supports [alttext.ai](https://alttext.ai/) only.

| Variable | Required | Description |
| --- | --- | --- |
| ALT_TEXT_URL | No | Base URL for the Alt Text AI service. Only [alttext.ai](https://alttext.ai/) is currently supported. |
| ALT_TEXT_SECRET | No | API key/secret for the alttext.ai service. |
| ALT_TEXT_ENABLED | No | Enable/disable automatic alt text generation (`true`/`false`). |
| ALT_TEXT_USER_TOGGLE | No | Require user opt-in for automatic alt text generation when `true`, unless `SKIP_ALT_TEXT_USER_SETTING` is enabled. |
| SKIP_ALT_TEXT_USER_SETTING | No | Bypass the per-user alt text setting when `true`; this takes precedence over `ALT_TEXT_USER_TOGGLE`. |

## Domain and channel configuration

| Variable | Required | Description |
| --- | --- | --- |
| LOCAL_DOMAIN | No | Local domain for the Mastodon instance (for example: example.social). Used for deep links and channel detection. |
| MAIN_CHANNEL | No | Enable main channel mode (used by the status ban worker). |
| AUTO_FOLLOW_ENABLED | No | Enable/disable env-configured auto-follow for newly registered users (`true`/`false`). Used when no dashboard auto-follow list is configured for this instance. |
| AUTO_FOLLOW_ACCOUNTS | No | Comma-separated list of accounts to auto-follow on registration when no dashboard list is configured. An enabled dashboard list takes precedence; a disabled list turns auto-follow off. |
| WELCOME_EMAIL_DISABLED | No | Disable welcome email for newly registered users (`true` disables sending). |

## Signup restrictions

| Variable | Required | Description |
| --- | --- | --- |
| ALLOWED_SIGNUP_EMAIL_DOMAIN | No | Comma-separated email domains allowed to sign up. All domains are allowed if not set. |

## Cross-instance push notifications

| Variable | Required | Description |
| --- | --- | --- |
| CROSS_INSTANCE_PUSH_TARGET_URL | No | Full URL of the partner instance's `/api/v1/cross_instance_push` endpoint. Sending is enabled only when this and the secret are both set. |
| CROSS_INSTANCE_PUSH_SECRET | Yes (if used) | Secret shared with the partner instance, used for outbound and inbound push requests. |

## For You timeline

| Variable | Required | Description |
| --- | --- | --- |
| FOR_YOU_TIMELINE_ENABLED | No | Enable the For You timeline behaviour (`true`/`false`). |
| FOR_YOU_TIMELINE_CHANNELS | No | Comma-separated channel usernames that also boost through the custom boost bot. |

## Status reactions

| Variable | Required | Description |
| --- | --- | --- |
| PATCHWORK_STATUS_REACTION_NAMES | No | Comma-separated emoji allowed as status reactions (default: 👍,❤️,😂,😮,😠). |
| PATCHWORK_STATUS_REACTION_EMOJI_LIMIT | No | Maximum emoji reactions (default: 5). |

## Custom relay and instances timeline

The custom relay timeline feature subscribes the host Mastodon instance to FediBuzz relay URLs,
stores delivered statuses in per-domain Redis feeds, and exposes a merged home + instance timeline endpoint.

Configured domains are converted to relay inbox URLs in this format:

```text
https://relay.fedi.buzz/instance/<domain>
```

Example:

```bash
CUSTOM_RELAY_DOMAINS=mastodon.social,mastodon.beer
```

| Variable | Required | Description |
| --- | --- | --- |
| CUSTOM_RELAY_DOMAINS | No | Comma-separated source instance domains to subscribe to via FediBuzz relay endpoints. Example: mastodon.social,mastodon.beer. |

Stored statuses use Redis sorted sets:

```text
feed:relay:<sanitized-domain>
```

Example:

```text
feed:relay:mastodon-social
```

The instances timeline endpoint always includes the authenticated user's home timeline and can include one, many, or all enabled relay domains:

```text
GET /api/v1/timelines/instances_timeline
GET /api/v1/timelines/instances_timeline?domain=mastodon.social
GET /api/v1/timelines/instances_timeline?domain=mastodon.social,mastodon.beer
GET /api/v1/timelines/instances_timeline?domain[]=mastodon.social&domain[]=mastodon.beer
```

To verify stored statuses from Rails console:

```ruby
domain = 'mastodon.social'
key = NewsmastMastodon::RelayFeed.timeline_key(domain)

RedisConnection.with do |redis|
  puts redis.zcard(key)
  puts redis.zrevrange(key, 0, 10)
end
```
