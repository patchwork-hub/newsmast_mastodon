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
- [CI jobs](#ci-jobs)
- [API validation and system testing](#api-validation-and-system-testing)
- [Community and support](#community-and-support)
- [Troubleshooting](#troubleshooting)
- [Changelog](#changelog)
- [License](#license)

## Release and upgrade quick links

- Release notes: [CHANGELOG.md](CHANGELOG.md)
- Contribution and release process: [CONTRIBUTING.md](CONTRIBUTING.md)
- Mastodon upgrade runbook: [docs/internal/mastodon-upgrade/RUNBOOK.md](docs/internal/mastodon-upgrade/RUNBOOK.md)

Migration-aligned external references:

- Foundation mastodon repo: https://github.com/TheNewsmastFoundation/newsmast-mastodon
- Foundation documentation index: https://github.com/TheNewsmastFoundation/documentation/tree/main/newsmast-mastodon

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

- Contribution workflow: [CONTRIBUTING.md](CONTRIBUTING.md)
- Maintainer roles and ownership: [MAINTAINERS.md](MAINTAINERS.md)
- Code ownership policy: [.github/CODEOWNERS](.github/CODEOWNERS)
- Governance and merge policy: [GOVERNANCE.md](GOVERNANCE.md)
- Security reporting policy: [SECURITY.md](SECURITY.md)
- Automated security scanning workflow: [.github/workflows/security.yml](.github/workflows/security.yml)

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
- [config/initializers/prepend_concerns.rb](config/initializers/prepend_concerns.rb): wiring that prepends/includes engine concerns into host classes.
- [lib/newsmast_mastodon/engine.rb](lib/newsmast_mastodon/engine.rb): engine boot behavior, route mounting, migration path appends, host compatibility checks.
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

See [config/routes.rb](config/routes.rb) for the full route list.

## Environment variables

The full runtime variable reference is maintained in:

- [docs/configuration/environment-variables.md](docs/configuration/environment-variables.md)

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

For detailed local service setup, Docker-backed infrastructure runs, and test
notes, see:

- [docs/development/testing-and-local-services.md](docs/development/testing-and-local-services.md)

## CI jobs

For the complete CI job matrix and requirements, see:

- [docs/ci/jobs.md](docs/ci/jobs.md)

## API validation and system testing

Use the API validation guide for route/documentation checks, Newman execution,
smoke tests, and full check orchestration:

- [docs/testing/api-validation-and-system-testing.md](docs/testing/api-validation-and-system-testing.md)

Contribution process and standards are documented in [CONTRIBUTING.md](CONTRIBUTING.md).

## Community and support

- Support and help channels: [SUPPORT.md](SUPPORT.md)
- Contribution workflow and policy: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security reporting process: [SECURITY.md](SECURITY.md)
- Community code of conduct: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- Maintainer roles and ownership: [MAINTAINERS.md](MAINTAINERS.md)
- Project governance and merge policy: [GOVERNANCE.md](GOVERNANCE.md)

## Troubleshooting

Common troubleshooting notes are documented in:

- [docs/troubleshooting/common-issues.md](docs/troubleshooting/common-issues.md)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## License

This project is licensed under the GNU Affero General Public License v3.0.
See [LICENSE.txt](LICENSE.txt) for details, and [NOTICE](NOTICE) for attribution guidance.
