# Environment Variables

This page lists runtime environment variables supported by newsmast_mastodon.

## Deep linking

| Variable | Required | Description |
| --- | --- | --- |
| IOS_APP_ID | Yes (for iOS) | Full iOS app identifier in TeamID.BundleID format (for example: VA45Q6RWV3.com.csidnetwork.social). AASA returns 404 if not set. |
| IOS_DEEPLINK_PATHS | No | Comma-separated URL path patterns (defaults to /@*,/@*/*). |
| ANDROID_PACKAGE_NAME | Yes (for Android) | Android app package name (for example: com.csidnetwork.social). Asset links returns 404 if not set. |
| ANDROID_SHA256_CERT_FINGERPRINTS | Yes (for Android) | Comma-separated SHA-256 certificate fingerprints for Android app verification. Asset links returns 404 if not set. |
| IOS_APP_STORE_URL | No | iOS App Store link for email footers. |
| ANDROID_APP_STORE_URL | No | Google Play Store link for email footers. |

## CiviCRM membership check

| Variable | Required | Description |
| --- | --- | --- |
| CSID_MEMBERSHIP_CHECK_ENABLED | No | Enable/disable CiviCRM membership verification (default: false). |
| CIVICRM_BASE_URL | Yes (if enabled) | Base URL for CiviCRM instance (for example: https://civicrm.example.com). |
| CIVICRM_AUTH_TOKEN | Yes (if enabled) | CiviCRM API authentication token. Include Bearer prefix or it will be added automatically. |
| CSID_MEMBERSHIP_ALLOWLIST_EMAILS | No | Comma-separated email addresses that bypass the CiviCRM membership check. |

## Firebase notifications

| Variable | Required | Description |
| --- | --- | --- |
| FIREBASE_PROJECT_ID | No | Firebase project ID for push notifications. |
| FIREBASE_KEY_FILE_NAME | No | Path to Firebase service account key JSON file. |

## Ghost integration

| Variable | Required | Description |
| --- | --- | --- |
| GHOST_URL | No | Ghost CMS instance URL (auto-added to config.hosts if set). |
| GHOST_ADMIN_API_KEY | No | Ghost Admin API key for content access. |
| GHOST_WEBHOOK_ID | No | Ghost webhook ID for updates. |
| GHOST_WEBHOOK_TARGET_URL | No | Target URL for Ghost webhook callbacks. |
| GHOST_WEBHOOK_SECRET | No | Secret token for Ghost webhook verification. |
| GHOST_NOTIFICATION_SENDER_NAME | No | Sender name for Ghost-related notifications (default: Development Patchwork). |

## Reblog and boost services

| Variable | Required | Description |
| --- | --- | --- |
| REBLOG_ENABLED | No | Enable reblog functionality (set to true to enable). |
| REBLOG_INSTANCE_URL | No | Mastodon instance URL for reblog operations. |
| REBLOG_EMAIL | No | Email account for reblog authentication. |
| REBLOG_PASSWORD | No | Password for reblog authentication. |
| REBLOG_CLIENT_ID | Yes (if reblog enabled) | OAuth client ID for reblog instance. |
| REBLOG_CLIENT_SECRET | Yes (if reblog enabled) | OAuth client secret for reblog instance. |
| BOOST_POST_INSTANCE_URL | No | Boost instance URL for post boosting. |
| BOOST_POST_API_KEY | No | API key for Boost post service. |
| BOOST_POST_API_SECRET | No | API secret for Boost post service. |
| BOOST_POST_USERNAME | No | Username for Boost account. |
| BOOST_POST_USER_DOMAIN | No | Domain for Boost account user. |
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
| ARTICLE_NOTIFICATION_SENDER_NAME | No | Sender name for article-related notifications (default: Development Patchwork). |

## Alt text AI

| Variable | Required | Description |
| --- | --- | --- |
| ALT_TEXT_URL | No | Base URL for Alt Text AI service. |
| ALT_TEXT_SECRET | No | API key/secret for Alt Text AI service. |

## Domain and channel configuration

| Variable | Required | Description |
| --- | --- | --- |
| LOCAL_DOMAIN | No | Local domain for the Mastodon instance (for example: example.social). Used for deep links and channel detection. |
| MAIN_CHANNEL | No | Enable main channel mode (affects login behavior). |
| AUTO_FOLLOW_ACCOUNTS | No | Comma-separated list of accounts to auto-follow on user registration. |

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

Legacy relay routes are also routed to the same behavior:

```text
GET /api/v1/timelines/relay
GET /api/v1/timelines/relay/:domain
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

## WordPress integration

| Variable | Required | Description |
| --- | --- | --- |
| WORDPRESS_URL | No | WordPress instance URL (auto-added to config.hosts if set). |
