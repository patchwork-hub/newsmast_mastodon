# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses compatibility-first versioning (`X.Y.Z.N`, where `X.Y.Z`
tracks the target Mastodon version and `N` is the gem patch level).

## [Unreleased]

## [4.6.5.0] - 2026-08-10

### Added

- Added upgrade report and runbook tracking for Mastodon 4.6.5.
- Added `app/javascript/mastodon/features/compose/containers/compose_form_container.js` to the frontend override drift manifest.

### Changed

- Bumped compatibility contract to Mastodon 4.6.5 (`VERSION = "4.6.5.0"`, `mastodon_version_requirement = "4.6.5"`).

## [4.6.3.0] - 2026-07-24

### Added

- Documented and prepared the upgrade path for Mastodon 4.6.3 in the internal upgrade runbooks and reports.
- Added runtime dependencies `jwt`, `faraday`, and `parslet` to `newsmast_mastodon.gemspec`, pinned to the compatible version lines used by Mastodon 4.6.3.
- Added `docs/internal/peer-dependencies.md` documenting gems supplied by the host Mastodon application and the engine's own runtime dependencies.
- Added `SUPPORT.md` with support routing and response expectations.
- Added `MAINTAINERS.md` to document ownership and review responsibilities.
- Added `GOVERNANCE.md` with decision, merge, and release policy.
- Added `config/data/README.md` with starter-pack data provenance guidance.
- Added per-directory provenance records under `config/data/*/PROVENANCE.md`.
- Added `NOTICE` with license and dependency attribution guidance.
- Added `newsmast_mastodon:backfill_csid_badge_fields` rake task to populate blank account profile fields from CSID CiviCRM membership groups, with `DRY_RUN`, `BATCH_SIZE`, and `EMAIL` targeting support.

### Changed

- Aligned `newsmast_mastodon.gemspec` with host Mastodon 4.6.3: Rails `~> 8.1.0`, Ruby `>= 3.3.0, < 4.1.0`, Sidekiq `~> 8.1.0` for development, and host-compatible runtime dependency lines.
- Updated `CODE_OF_CONDUCT.md` enforcement contact details.
- Expanded `CONTRIBUTING.md` with versioning, breaking-change, and release guidance.
- Aligned `CONTRIBUTING.md` release checklist with checksum and provenance attestation workflow steps.
- Added community/governance/support links to `README.md`.
- Linked non-security conduct reporting path from `SECURITY.md`.
- Hardened release workflow with checksum generation and build provenance attestation.
- Cross-linked governance, maintainer, and support documents for easier navigation.
- Refactored CI workflows to use a shared runtime setup action, added per-job timeouts, and introduced `ci-ok` as a stable aggregate required check.
- Added `no-changelog` PR label bypass support to `changelog-policy` for approved non-behavioral changes.
- Dropped end-of-life Ruby 3.1 from CI and aligned the pipeline with the declared support floor; CI now runs on Ruby 3.2, 3.3, and 3.4. Documented CI Ruby version coverage in `README.md`, `CONTRIBUTING.md`, and `docs/ci/jobs.md`.
- Expanded security automation with `bundler-audit` and workflow linting (`actionlint` + `zizmor`) and tightened dependency-review severity gating.
- Hardened release gating with a protected `rubygems` environment and verification that release tags are ancestors of `main`.
- Updated branch/tag ruleset definitions to require the new checks, enforce linear history, protect `v*` tags, and skip Copilot review on draft PRs.
- Grouped Dependabot major updates for Bundler and GitHub Actions to reduce update noise.
- Updated CSID signup flow to persist up to four `CSID Badge` account fields from CiviCRM `user_groups` (excluding `Newsletter sign-up`) during account creation.
- Expanded `NewsmastMastodon::CivicrmMembershipCheckService` to return extracted `user_groups`, support `force_remote:` checks, and handle multiple CiviCRM response shapes more robustly.
- Adjusted mention notification copy selection in `CustomNotificationService` to account for notification request presence together with direct/public visibility.

### Fixed

- Fixed `spec/dummy/db/schema.rb` declaring `ActiveRecord::Schema[8.1]`, which broke Postgres-backed specs under Rails 8.0 by causing `maintain_test_schema!` to abort and leave bootstrap tables unreachable.

## [4.5.11] - 2026-06-15

### Fixed

- Resolved single-gem sync regressions in the consolidated engine.
- Fixed API V1 behavior across account, channel, timeline, settings, webhook,
    notification token, drafted status, and local-only post endpoints.
- Aligned search indexing and support layers (Chewy indexes, authentication/user
    preparation concerns, helper behavior, and spec/dummy routing harnesses).
