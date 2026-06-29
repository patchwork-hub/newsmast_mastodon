# newsmast_mastodon

[![CI](https://github.com/patchwork-hub/newsmast_mastodon/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/patchwork-hub/newsmast_mastodon/actions/workflows/ci.yml)
[![Security](https://github.com/patchwork-hub/newsmast_mastodon/actions/workflows/security.yml/badge.svg?branch=main)](https://github.com/patchwork-hub/newsmast_mastodon/actions/workflows/security.yml)

`newsmast_mastodon` is a Rails engine that extends a Mastodon
host app with Newsmast features across accounts, content filtering,
conversations, custom feeds, local-only posts, posting workflows, and timeline
behavior.

## Release and upgrade quick links

- Release notes: `CHANGELOG.md`
- Contribution and release process: `CONTRIBUTING.md`
- Mastodon upgrade runbook: `docs/internal/mastodon-upgrade/RUNBOOK.md`

## Project scope

This gem is maintained by Patchwork Hub and targets deployments that need the
Newsmast feature set on top of Mastodon.

- Intended audience: teams running a Mastodon host app aligned with Newsmast behavior.
- Runtime target: Mastodon 4.5.11.
- Compatibility strategy: use exact gem version pinning and upgrade intentionally.

If you need a generic Mastodon extension point without Newsmast-specific
behavior, review your requirements before adopting this gem.

## Maintainer workflow

Project process and review ownership are documented here:

- Contribution workflow: `CONTRIBUTING.md`
- Maintainer roles and ownership: `MAINTAINERS.md`
- Code ownership policy: `.github/CODEOWNERS`
- Governance and merge policy: `GOVERNANCE.md`
- Security reporting policy: `SECURITY.md`
- Automated security scanning workflow: `.github/workflows/security.yml`

## What this gem adds

- API endpoints under `api/v1` for Newsmast account and feed workflows
- Draft status APIs and publish workflow
- Local-only post settings support
- Feed and timeline extensions (including custom timeline endpoints)
- Account and notification-related enhancements
- Host-app concern/service prepends for Mastodon models and services
- Install task for Chewy indexes and frontend override files
- Deep linking support for iOS Universal Links and Android App Links

## Architecture overview

Key areas of the codebase and their responsibilities:

- `app/controllers/newsmast_mastodon/api/v1/`: Newsmast API endpoints and request entry points.
- `app/services/newsmast_mastodon/`: business logic for feeds, notifications, login, relay workflows, and integrations.
- `app/lib/newsmast_mastodon/overrides/` and `app/models/concerns/newsmast_mastodon/`: host Mastodon extensions and behavior overrides.
- `config/initializers/prepend_concerns.rb`: wiring that prepends/includes engine concerns into host classes.
- `lib/newsmast_mastodon/engine.rb`: engine boot behavior, route mounting, migration path appends, host compatibility checks.
- `app/workers/newsmast_mastodon/`: async/background jobs.
- `app/serializers/` and `app/presenters/`: API shaping and response presentation.
- `db/migrate/`: engine migrations copied into the host app migration path.
- `spec/`: standalone and compatibility test coverage.

## Installation

Add the gem to your Mastodon host app with a strict version constraint:

```ruby
gem "newsmast_mastodon", "4.5.11"
```

**Important:** Do NOT use flexible version constraints like `~> 4.5` or `>= 4.5.11`, as these allow minor/patch version bumps that may not be compatible with your Mastodon version. Always pin to the exact version (e.g., `"4.5.11"`).

Install dependencies:

```bash
bundle install
```

Install Chewy indexes and frontend overrides into the host app:

```bash
bin/rails newsmast_mastodon:install
```

Run database migrations (the engine appends its own migrations to the host app):

```bash
bin/rails db:migrate
```

If frontend files were copied/updated, rebuild frontend assets in the host app:

```bash
yarn build:development
# or
yarn build:production
```

## Compatibility

- Ruby: `>= 3.1.0`
- Rails: `>= 7.1`, `< 9.0`
- Host app: Mastodon 4.5.11 runtime target

### Tested compatibility matrix

| Gem version | Mastodon | Ruby | Rails | Support |
| --- | --- | --- | --- | --- |
| 4.5.11 | 4.5.11 | 3.1 - 3.3 | 7.1 - 8.x | Active |

This gem is maintained against Mastodon 4.5.11. Use exact gem version pinning
in your host app Gemfile to avoid unplanned compatibility drift.

## Runtime behavior

- The engine mounts itself at `/` in the host app.
- The engine prepends/includes Newsmast concerns and overrides into Mastodon
  classes during `to_prepare`.
- The engine appends gem migrations to the host migration path automatically.
- If Ghost/WordPress environment variables are present, related hosts are
  allowlisted in `config.hosts`.
- If deep linking environment variables are set, `/.well-known/apple-app-site-association`
  and `/.well-known/assetlinks.json` serve the corresponding configuration;
  otherwise they return 404.

## Example endpoints

The engine defines multiple `api/v1` routes, including:

- `POST /api/v1/drafted_statuses`
- `POST /api/v1/drafted_statuses/:id/publish`
- `GET /api/v1/timelines/:username/feed`
- `GET /api/v1/local_only_posts/getLocalOnlySetting`
- `GET /.well-known/apple-app-site-association` — iOS Universal Links (AASA)
- `GET /.well-known/assetlinks.json` — Android App Links

See `config/routes.rb` for the full route list.

### Deep linking environment variables

| Variable | Required | Description |
| --- | --- | --- |
| `IOS_APP_ID` | Yes (for iOS) | Full iOS app identifier in `TeamID.BundleID` format (e.g., `VA45Q6RWV3.com.csidnetwork.social`). AASA returns 404 if not set. |
| `IOS_DEEPLINK_PATHS` | No | Comma-separated URL path patterns (defaults to `/@*,/@*/*`). |
| `ANDROID_PACKAGE_NAME` | Yes (for Android) | Android app package name (e.g., `com.csidnetwork.social`). Asset links returns 404 if not set. |
| `ANDROID_SHA256_CERT_FINGERPRINTS` | Yes (for Android) | Comma-separated SHA-256 certificate fingerprints for Android app verification. Asset links returns 404 if not set. |
| `IOS_APP_STORE_URL` | No | iOS App Store link for email footers. |
| `ANDROID_APP_STORE_URL` | No | Google Play Store link for email footers. |

### CiviCRM membership check environment variables

| Variable | Required | Description |
| --- | --- | --- |
| `CSID_MEMBERSHIP_CHECK_ENABLED` | No | Enable/disable CiviCRM membership verification (default: `false`). |
| `CIVICRM_BASE_URL` | Yes (if enabled) | Base URL for CiviCRM instance (e.g., `https://civicrm.example.com`). |
| `CIVICRM_AUTH_TOKEN` | Yes (if enabled) | CiviCRM API authentication token. Include `Bearer` prefix or it will be added automatically. |
| `CSID_MEMBERSHIP_ALLOWLIST_EMAILS` | No | Comma-separated email addresses that bypass the CiviCRM membership check. |

### Firebase notification environment variables

| Variable | Required | Description |
| --- | --- | --- |
| `FIREBASE_PROJECT_ID` | No | Firebase project ID for push notifications. |
| `FIREBASE_KEY_FILE_NAME` | No | Path to Firebase service account key JSON file. |

### Ghost integration environment variables

| Variable | Required | Description |
| --- | --- | --- |
| `GHOST_URL` | No | Ghost CMS instance URL (auto-added to `config.hosts` if set). |
| `GHOST_ADMIN_API_KEY` | No | Ghost Admin API key for content access. |
| `GHOST_WEBHOOK_ID` | No | Ghost webhook ID for updates. |
| `GHOST_WEBHOOK_TARGET_URL` | No | Target URL for Ghost webhook callbacks. |
| `GHOST_WEBHOOK_SECRET` | No | Secret token for Ghost webhook verification. |
| `GHOST_NOTIFICATION_SENDER_NAME` | No | Sender name for Ghost-related notifications (default: `Development Patchwork`). |

### Reblog/Boost services environment variables

| Variable | Required | Description |
| --- | --- | --- |
| `REBLOG_ENABLED` | No | Enable reblog functionality (set to `true` to enable). |
| `REBLOG_INSTANCE_URL` | No | Mastodon instance URL for reblog operations. |
| `REBLOG_EMAIL` | No | Email account for reblog authentication. |
| `REBLOG_PASSWORD` | No | Password for reblog authentication. |
| `REBLOG_CLIENT_ID` | Yes (if reblog enabled) | OAuth client ID for reblog instance. |
| `REBLOG_CLIENT_SECRET` | Yes (if reblog enabled) | OAuth client secret for reblog instance. |
| `BOOST_POST_INSTANCE_URL` | No | Boost instance URL for post boosting. |
| `BOOST_POST_API_KEY` | No | API key for Boost post service. |
| `BOOST_POST_API_SECRET` | No | API secret for Boost post service. |
| `BOOST_POST_USERNAME` | No | Username for Boost account. |
| `BOOST_POST_USER_DOMAIN` | No | Domain for Boost account user. |
| `BOOST_COMMUNITY_BOT_URL` | No | Boost community bot instance URL. |
| `BOOST_COMMUNITY_BOT_API_KEY` | No | API key for Boost community bot. |

### Custom boost bot environment variables

| Variable | Required | Description |
| --- | --- | --- |
| `{USERNAME}_INSTANCE_URL` | No | Mastodon instance URL for custom boost bot (replace `{USERNAME}` with bot username in uppercase). |
| `{USERNAME}_CLIENT_ID` | No | OAuth client ID for custom boost bot instance. |
| `{USERNAME}_CLIENT_SECRET` | No | OAuth client secret for custom boost bot instance. |

### Mail and branding environment variables

| Variable | Required | Description |
| --- | --- | --- |
| `MAIL_SENDER_NAME` | No | Sender name for email notifications (default: `Development Patchwork`). |
| `MAIL_LOGO_URL` | No | Logo URL for email headers. Defaults to Patchwork demo asset URL if not set. |
| `PRIVACY_POLICY_URL` | No | Privacy policy URL for email footers. |
| `TERMS_AND_CONDITIONS_URL` | No | Terms of service URL for email footers. |

### Notification services environment variables

| Variable | Required | Description |
| --- | --- | --- |
| `NOTIFICATION_SENDER_NAME` | No | Sender name for push notifications (default: `Development Patchwork`). |
| `SKIP_SIGNUP_PUSH_NOTI` | No | Skip sending push notifications on signup (set to `true` to skip). |
| `ARTICLE_NOTIFICATION_SENDER_NAME` | No | Sender name for article-related notifications (default: `Development Patchwork`). |

### Alt text AI environment variables

| Variable | Required | Description |
| --- | --- | --- |
| `ALT_TEXT_URL` | No | Base URL for Alt Text AI service. |
| `ALT_TEXT_SECRET` | No | API key/secret for Alt Text AI service. |

### Domain and channel configuration environment variables

| Variable | Required | Description |
| --- | --- | --- |
| `LOCAL_DOMAIN` | No | Local domain for the Mastodon instance (e.g., `example.social`). Used for deep links and channel detection. |
| `MAIN_CHANNEL` | No | Enable main channel mode (affects login behavior). |
| `AUTO_FOLLOW_ACCOUNTS` | No | Comma-separated list of accounts to auto-follow on user registration. |

### Custom relay / instances timeline environment variables

The custom relay timeline feature subscribes the host Mastodon instance to

## FediBuzz instance relay URLs, stores delivered statuses in per-domain Redis

feeds, and exposes a merged home + instance timeline endpoint.

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
| `CUSTOM_RELAY_DOMAINS` | No | Comma-separated source instance domains to subscribe to via #FediBuzz relay endpoints. Example: `mastodon.social,mastodon.beer`. |

Stored statuses use Redis sorted sets:

```text
feed:relay:<sanitized-domain>
```

Example:

```text
feed:relay:mastodon-social
```

The instances timeline endpoint always includes the authenticated user's home
timeline and can include one, many, or all enabled relay domains:

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

### WordPress integration environment variables

| Variable | Required | Description |
| --- | --- | --- |
| `WORDPRESS_URL` | No | WordPress instance URL (auto-added to `config.hosts` if set). |

## Development

Set up and run checks:

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

### Standalone Test Run With Docker Services

Use Docker only for infrastructure (PostgreSQL, Redis, Elasticsearch), while
running the Rails app and specs directly on your machine.

From your workspace root, start services:

```bash
docker compose up -d db redis es
```

From `newsmast_mastodon`, run specs against those services:

```bash
export DATABASE_HOST=127.0.0.1
export DATABASE_PORT=5432
export DATABASE_USER=postgres
export DATABASE_PASSWORD=postgres
export REDIS_HOST=127.0.0.1
export REDIS_PORT=6379
export ES_ENABLED=true
export ES_HOST=127.0.0.1
export ES_PORT=9200

bundle exec rspec --format progress
```

Optional cleanup:

```bash
docker compose down
```

Note: `RAILS_ENV=test bin/rails app:db:prepare` can fail if duplicate migration
names exist in the consolidated migration set. In that case, run specs directly
as above until migration naming conflicts are resolved.

## API validation and system testing

This repository includes a full API verification workflow for the consolidated
gem routes and a combined Postman collection.

### 1) Verify route/controller/doc sync

```bash
ruby script/api/verify_routes_and_docs.rb
# or
bundle exec rake api:verify
```

This checks:

- every expected route has a matching controller action
- every route appears in the combined Postman collection under `docs/`
- every Postman entry maps to a real route

### 2) Run the combined Postman collection with Newman

```bash
BASE_URL=http://localhost:3000 \
ACCESS_TOKEN=... \
bash script/api/run_newman_suite.sh

# or
BASE_URL=http://localhost:3000 ACCESS_TOKEN=... bundle exec rake api:postman
```

The runner does a setup step first (`script/api/postman_setup.rb`) to generate
`tmp/newman.generated.env.json`, including dynamic IDs such as:

- `account_id`
- `username`
- `drafted_status_id` (if draft creation succeeds)
- `relay_id` (if relay creation succeeds)

You can disable auto setup and use a custom environment file:

```bash
AUTO_SETUP=0 POSTMAN_ENV_FILE=script/api/newman.env.staging.template.json \
bash script/api/run_newman_suite.sh
```

Templates for local and staging are available in `script/api/`.

### 3) Run request-spec smoke layer

```bash
bash script/api/run_rspec_smoke.sh
# or
bundle exec rake api:smoke
```

### 4) Run complete check sequence

```bash
BASE_URL=http://localhost:3000 ACCESS_TOKEN=... bundle exec rake api:full_check
```

Contribution process and standards are documented in `CONTRIBUTING.md`.

## Community and support

- Support and help channels: `SUPPORT.md`
- Contribution workflow and policy: `CONTRIBUTING.md`
- Security reporting process: `SECURITY.md`
- Community code of conduct: `CODE_OF_CONDUCT.md`
- Maintainer roles and ownership: `MAINTAINERS.md`
- Project governance and merge policy: `GOVERNANCE.md`

## Changelog

See `CHANGELOG.md` for release notes.

## License

This project is licensed under the GNU Affero General Public License v3.0.
See `LICENSE.txt` for details, and `NOTICE` for attribution guidance.
