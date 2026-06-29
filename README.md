# newsmast_mastodon

[![CI](https://github.com/patchwork-hub/newsmast_mastodon/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/patchwork-hub/newsmast_mastodon/actions/workflows/ci.yml)
[![Security](https://github.com/patchwork-hub/newsmast_mastodon/actions/workflows/security.yml/badge.svg?branch=main)](https://github.com/patchwork-hub/newsmast_mastodon/actions/workflows/security.yml)

`newsmast_mastodon` is a Rails engine that extends a Mastodon
host app with Newsmast features across accounts, content filtering,
conversations, custom feeds, local-only posts, posting workflows, and timeline
behavior.

## Table of contents

- [Release and upgrade quick links](#release-and-upgrade-quick-links)
- [Project scope](#project-scope)
- [Maintainer workflow](#maintainer-workflow)
- [What this gem adds](#what-this-gem-adds)
- [Architecture overview](#architecture-overview)
- [Installation](#installation)
- [Compatibility](#compatibility)
- [Runtime behavior](#runtime-behavior)
- [Example endpoints](#example-endpoints)
- [Environment variables](#environment-variables)
- [Development](#development)
- [CI jobs explained](#ci-jobs-explained)
- [API validation and system testing](#api-validation-and-system-testing)
- [Community and support](#community-and-support)
- [Troubleshooting](#troubleshooting)
- [Changelog](#changelog)
- [License](#license)

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

## Environment variables

The full runtime variable reference is maintained in:

- `docs/configuration/environment-variables.md`

Quick index:

- Deep linking
- CiviCRM membership check
- Firebase notifications
- Ghost integration
- Reblog and boost services
- Custom boost bot
- Mail and branding
- Notification services
- Alt text AI
- Domain and channel configuration
- Custom relay and instances timeline
- WordPress integration

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

## CI jobs explained

| Workflow | Job | Purpose | Requirements |
| --- | --- | --- | --- |
| `CI` | `changelog-policy` | Ensures PRs that touch code/workflows update `CHANGELOG.md`. | Pull request event. |
| `CI` | `lint` | Runs RuboCop across supported Ruby versions. | Ruby 3.1, 3.2, 3.3 matrix. |
| `CI` | `api-contract` | Verifies route/controller/Postman docs sync via `bundle exec rake api:verify`. | No external services required. |
| `CI` | `test` | Runs main RSpec suite (sqlite mode by default) and uploads coverage artifacts. | Redis service; Ruby 3.1, 3.2, 3.3 matrix. |
| `CI` | `test-postgres-subset` | Validates targeted model specs against real Postgres schema bootstrap. | Postgres + Redis services; Ruby 3.3. |
| `CI` | `compatibility` | Runs upgrade-safety and version-sync compatibility specs. | Ruby 3.3. |
| `CI` | `host-integration` | Optional host Mastodon integration checks and override drift validation. | `HOST_MASTODON_REPO` (+ optional `HOST_MASTODON_REF`) and `HOST_MASTODON_TOKEN`. |
| `Security` | `dependency-review` | Detects risky dependency changes in pull requests. | Pull request event. |
| `Security` | `codeql` | Runs scheduled and event-driven Ruby CodeQL static analysis. | `security-events: write` permission. |

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

## Troubleshooting

### Commit fails with GPG signing error

If commit signing is enabled but GPG is not configured correctly, commits can
fail with errors such as `failed to write commit object`.

Use one of the following:

```bash
git commit --no-gpg-sign -m "<message>"
# or disable signing for this repository
git config commit.gpgsign false
```

### Host-integration workflow shows variable/secret warnings in editors

Some editors warn about unknown `vars.*` or `secrets.*` keys in
`.github/workflows/ci.yml` for the optional `host-integration` job. This is
expected when repository/org variables are not defined locally.

Define these in repository settings if you use host integration:

- `HOST_MASTODON_REPO`
- `HOST_MASTODON_REF` (optional)
- `HOST_MASTODON_TOKEN`

### `bundle exec rake api:verify` route/doc mismatch on `{{id}}`

If Postman paths use `{{id}}`, route verification should normalize that to
`:id`. Ensure the verifier includes normalization for both explicit id aliases
and bare `id` placeholders.

## Changelog

See `CHANGELOG.md` for release notes.

## License

This project is licensed under the GNU Affero General Public License v3.0.
See `LICENSE.txt` for details, and `NOTICE` for attribution guidance.
