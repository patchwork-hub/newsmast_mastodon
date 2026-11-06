# Features

This page covers the main features the gem adds to Mastodon. For environment variables see [Configuration](configuration.md).

## Contents

- [Accounts](#accounts)
- [Content filters](#content-filters)
- [Custom feeds](#custom-feeds)
- [Posts](#posts)

## Accounts

Endpoints live under `/api/v1`. Unless noted, they need an OAuth token with `read write` scopes and a signed-in user.

### Sign-up

`POST /api/v1/accounts` is extended so that:

- the `reason` defaults to `Signing up via <LOCAL_DOMAIN> App` when empty;
- a 4-digit OTP is generated and emailed to the new user right after creation;
- sign-up is rejected unless the email domain is listed in `ALLOWED_SIGNUP_EMAIL_DOMAIN` (comma-separated; all domains are allowed when unset).

After a user is approved (`prepare_new_user!`):

1. **Auto-follow:** accounts are followed from the Dashboard auto-follow list for this instance if one exists (an enabled list wins; a disabled list turns auto-follow off). Otherwise the env fallback applies when `AUTO_FOLLOW_ENABLED=true`, using `AUTO_FOLLOW_ACCOUNTS`.
2. A welcome email is queued after one hour, unless `WELCOME_EMAIL_DISABLED=true`.
3. If `DEFAULT_EMAIL_NOTIFICATIONS_ENABLED` is set, all `notification_emails.*` settings start as `true` or `false` accordingly.
4. If the Dashboard setting `Automatic Search Opt-out` is on, the account is created non-discoverable and non-indexable.

`PATCH /api/v1/accounts/update_credentials` also redistributes the profile update to followers.

### Password and email

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/custom_passwords` | Start a password reset for an email: stores a reset token and OTP, emails the OTP. |
| GET | `/custom_passwords/request_otp` | Send a fresh OTP. |
| POST | `/custom_passwords/verify_otp` | Verify the OTP (also confirms the user, or completes an email change) and return an access token. |
| PATCH/PUT | `/custom_passwords/:id` | Set a new password with `password` and `password_confirmation`, after the OTP is verified. |
| POST | `/custom_passwords/change_password` | Authenticated change; needs `current_password`. |
| POST | `/custom_passwords/change_email` | Authenticated email change; confirmed via OTP. |

The first four endpoints do not require authentication.

### Notification tokens

Device tokens for Firebase push (`FIREBASE_PROJECT_ID`, `FIREBASE_KEY_FILE_NAME`).

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/notification_tokens` | Register `notification_token` and `platform_type`. |
| POST | `/notification_tokens/revoke_token` | Remove one token. |
| POST | `/notification_tokens/update_mute` | Set `mute` on all of the user's tokens. |
| GET | `/notification_tokens/get_mute_status` | Read the mute flag. |
| DELETE | `/notification_tokens/reset_device_tokens/:platform_type` | Remove all tokens for a platform. |

### Cross-instance push

`POST /api/v1/cross_instance_push` accepts push requests from a trusted partner instance. Requests must carry an `X-Signature` header of the form `t=<unix time>, sha256=<hmac>`, signed with `CROSS_INSTANCE_PUSH_SECRET`; timestamps older than 300 seconds are rejected. Body: `username`, `title` (1–255 chars), `body` (1–1000 chars), optional `data` (up to 10 keys, values up to 500 chars). Valid requests return `202` and are delivered by a Sidekiq worker. Outbound sending is on only when both `CROSS_INSTANCE_PUSH_TARGET_URL` and the secret are set.

### Settings

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/user_locales` | Save the user's locale (`lang`); `400` if unavailable. |
| GET / POST | `/patchwork/email_settings`, `/patchwork/email_settings/notification` | Read or toggle all email notifications at once (`allowed`). |
| GET / POST | `/patchwork/alttext_settings`, `/patchwork/alttext_settings/alttext` | Read or set automatic alt text (`enabled`). |
| GET | `/patchwork/conversations/check_conversation` | Latest conversation with `target_account_id`. |
| POST | `/patchwork/conversations/read_all` | Mark all conversations read. |

### Account deletion

- `POST /delete_account` with `password`: verifies the password, suspends the account and queues deletion (the username is reserved).
- `DELETE /patchwork/account_deletion/:id`: deletes an account immediately without reserving email or username.

### Deep links

`/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json` are served from the deep-link variables listed in [Configuration](configuration.md).

## Content filters

Content filters let a community or server operator hide unwanted statuses, hashtags and accounts by keyword. Rules are created in the Newsmast Dashboard and stored in the shared database; the gem enforces them.

### Data

| Table / model | Purpose |
| --- | --- |
| `server_settings` (`ServerSetting`) | Switches. `Content filters` and `Spam filters` turn each filter family on. |
| `keyword_filters` (`KeywordFilter`) | Global keywords. `filter_type` is `content`, `hashtag` or `both`. |
| `keyword_filter_groups` (`KeywordFilterGroup`) | Groups keywords under a server setting. |
| `patchwork_communities_filter_keywords` (`CommunityFilterKeyword`) | Per-community `filter_in` / `filter_out` keywords; `patchwork_community_id` NULL means global. |

The gem adds `is_banned` to `statuses` and `accounts`, and uses Mastodon's `listable` / `trendable` flags on tags.

### When a status is checked

- Remote statuses: queued (`BanStatusWorker`) when the record is created.
- Local statuses: queued after Mastodon finishes post-processing.

For each active keyword under an enabled filter family, `BanStatusService`:

1. Checks the author's username, display name and bio, and bans the account on a match.
2. For `hashtag` / `both` filters, makes matching tags unlistable and untrendable.
3. For `content` / `both` filters, matches the keyword as a whole word in the status text (HTML stripped, case-insensitive).
4. Records banned status IDs in Redis (`content_filters_banned_status_ids`, `spam_filters_banned_status_ids`, and a combined `excluded_status_ids`, capped at about 400 entries).

A banned status gets `is_banned = true`. If it is local, it is also marked sensitive with the spoiler text `Sensitive content!!!`. Statuses that are not banned continue to channel reblogging when channel mode is enabled (`MAIN_CHANNEL`, `BOOST_BOT_ENABLED`).

### Where banned content is hidden

- `Status.without_banned` and the `indexable` scope exclude banned statuses, so they do not appear in search indexes.
- Banned tags are excluded from tag lookups that respect `listable`.
- Feeds exclude IDs from `FeedService#excluded_status_ids` when the matching setting is on.
- Statuses from the `Threads` and `Bluesky` domains are excluded from a user's feeds when those server settings are on.

### Bulk re-scan workers

Run these from Sidekiq (or the console) after changing filters; they re-check existing data against all global keywords:

| Worker | Action |
| --- | --- |
| `StatusBannedWorker` | Bans existing statuses whose text matches. |
| `BanTagWorker` | Makes matching tags unlistable and bans their statuses. |
| `AccountBannedWorker` | Bans accounts whose domain, username, display name or bio matches. |

All three log progress and skip records that are already banned.

### Per-community filters

`BanStatusService#keyword_matches_in_status?` applies a community's `filter_in` and `filter_out` keywords (hashtag or text) when deciding whether a status belongs in that community's channel. Empty `filter_in` means everything is allowed; empty `filter_out` means nothing is excluded.

## Custom feeds

All endpoints are under `/api/v1/timelines` and return standard Mastodon status JSON.

### Channel feed

`GET /api/v1/timelines/@:username/feed`

Returns the custom timeline of a community boost-bot account (a Dashboard channel). Authentication is optional.

| Parameter | Meaning |
| --- | --- |
| `local`, `remote` | Restrict to local or remote statuses (ignored if both are set). |
| `only_media` | Only statuses with media. |
| `limit`, `max_id`, `since_id`, `min_id` | Standard pagination. |

Responses: `400` without a username, `404` if the account is unknown or not an active boost-bot community admin. Statuses come from the Redis sorted set `custom:<account_id>`, filtered to hide replies and reblogs, suspended or silenced accounts, and the viewer's language preferences. New statuses are added by `CustomFeedInsertWorker`.

### For You timeline

`GET /api/v1/timelines/for_you_custom_timeline` (authentication required, `read:statuses`)

Merges the user's home timeline with the shared local mix timeline (`feed:mix_channel_local_timeline`, the newest 400 public local statuses). It is filled only when `FOR_YOU_TIMELINE_ENABLED=true`.

Parameters: `limit`, `only_media`, `exclude_replies`, `exclude_direct_statuses`, `grouped_admin_statuses` (drops statuses from community admin accounts), `domain` (adds relay feeds, see below), plus pagination. The response includes `patchwork_post_reactions` for each status.

Boost-bot accounts can add or remove statuses in this shared timeline:

- `POST /api/v1/custom_statuses/add_custom_boost_bot_status`: params `client_id`, `client_secret`, `status_url`. Resolves the URL and adds the status.
- `POST /api/v1/custom_statuses/remove_custom_boost_bot_status`: params `client_id`, `client_secret`, `status_id`.

### Instances timeline

`GET /api/v1/timelines/instances_timeline` (authentication required, `read:statuses`)

Combines the user's home timeline with statuses delivered by relays from selected instances.

```text
GET /api/v1/timelines/instances_timeline
GET /api/v1/timelines/instances_timeline?domain=mastodon.social
GET /api/v1/timelines/instances_timeline?domain=mastodon.social,mastodon.beer
GET /api/v1/timelines/instances_timeline?domain[]=mastodon.social&domain[]=mastodon.beer
```

Parameters: `domain` (omit for all enabled relay domains), `only_media`, `exclude_replies`, `exclude_direct_statuses`, plus pagination. A domain that is not an enabled relay domain is rejected.

### Custom relays

Set `CUSTOM_RELAY_DOMAINS` to a comma-separated list of source instances:

```bash
CUSTOM_RELAY_DOMAINS=mastodon.social,mastodon.beer
```

`RelayEnvSyncWorker` (scheduler queue) subscribes the host to `https://relay.fedi.buzz/instance/<domain>` for each domain. Incoming statuses are stored per domain in Redis sorted sets named `feed:relay:<sanitized-domain>` (for example `feed:relay:mastodon-social`). Check a feed from the console:

```ruby
key = NewsmastMastodon::RelayFeed.timeline_key("mastodon.social")
RedisConnection.with { |redis| puts redis.zcard(key) }
```

Server owners can also manage relays over the API: `POST /api/v1/patchwork/relays` (`inbox_url`) and `DELETE /api/v1/patchwork/relays/:id`. Both require the Owner role.

### Other timeline changes

The home, public, list, tag, bookmarks, trends and account-status endpoints accept extra filters such as `exclude_direct_statuses`, `exclude_replies`, `only_reblogs` and `exclude_original_statuses`, and include `patchwork_post_reactions` in their responses.

## Posts

### Drafts

Drafts are stored server-side (`patchwork_drafted_statuses`). Limits per account: 300 drafts in total and 25 created per day.

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/drafted_statuses` | Create a draft. Takes the same params as a status. |
| GET | `/drafted_statuses` | List drafts, grouped by date, paginated. |
| GET | `/drafted_statuses/:id` | Show a draft. |
| PATCH/PUT | `/drafted_statuses/:id` | Replace a draft. |
| DELETE | `/drafted_statuses/:id` | Delete a draft. |
| POST | `/drafted_statuses/:id/publish` | Delete the draft and post it (or schedule it, if `scheduled_at` is set). |

Reading needs `read:statuses`; writing needs `write:statuses`. Media attached to a draft is kept for publishing.

### Long posts

If the Dashboard setting `Long posts` is on, its value replaces Mastodon's 500-character limit. The new limit is enforced when posting and is reported to clients in `configuration.statuses.max_characters` of the instance API (v1 and v2). Invalid or missing values fall back to 500.

### Local-only posts

`POST /api/v1/statuses` accepts `local_only`. Local-only posts are not federated. Replies inherit the parent's value when the client does not set one, and boosts copy the original's. Clients check whether the feature is on with `GET /api/v1/local_only_posts/getLocalOnlySetting`, which returns `{ "local_only": true|false }`.

### Reactions

Emoji reactions, one per user per status:

- `PUT /api/v1/patchwork/statuses/:status_id/reactions/:emoji`: set or change your reaction.
- `DELETE /api/v1/patchwork/statuses/:status_id/reactions/:emoji`: remove it.

Allowed emoji come from `PATCHWORK_STATUS_REACTION_NAMES` (default `👍,❤️,😂,😮,😠`), with at most `PATCHWORK_STATUS_REACTION_EMOJI_LIMIT` (default 5). Timelines, status and context responses include `patchwork_post_reactions`.

### Link previews

`GET /api/v1/utilities/link_preview?url=...` returns metadata for a URL. Errors: `400` for a missing or invalid URL, `422` if fetching fails.

### Alt text

When `ALT_TEXT_ENABLED=true`, alt text is generated for images on local posts through [alttext.ai](https://alttext.ai/) (`ALT_TEXT_URL`, `ALT_TEXT_SECRET`). Users opt in with the alt text setting unless `SKIP_ALT_TEXT_USER_SETTING=true`.

### Reblogging and boosting

- **Channel reblogging:** after a status passes content filters, `MAIN_CHANNEL` or `BOOST_BOT_ENABLED` triggers reblogging by channel accounts (`REBLOG_*` variables). Post URLs use `LOCAL_DOMAIN`.
- **Boost service:** `BOOST_POST_ENABLED` and `BOOST_POST_*` send posts to a remote boost API.
- **Custom boost bots:** `{USERNAME}_INSTANCE_URL`, `{USERNAME}_CLIENT_ID` and `{USERNAME}_CLIENT_SECRET` configure a named bot account.

