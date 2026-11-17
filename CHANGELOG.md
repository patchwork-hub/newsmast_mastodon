# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses compatibility-first versioning (`X.Y.Z.N`, where `X.Y.Z`
tracks the target Mastodon version and `N` is the gem patch level).

## [Unreleased]

## [4.6.10.0] - Unreleased

First gem release for Mastodon 4.6.10. Supersedes the `4.6.5.2`/`4.6.5.3`
version strings that were set on the development branch but never tagged or
published; their changes are listed here.

### Upgrade notes

- No new gem migrations. Mastodon 4.6.6–4.6.10 ship no core migrations.
- Re-run `bin/rails newsmast_mastodon:install` after upgrading (no vendored
  file changed upstream, but the install step is required on a fresh
  4.6.10 snapshot).
- Host Ruby is now 4.0.9 (within the supported `>= 3.3.0, < 4.1.0` range).

### Added

- Cross-instance push notification system and unread notification count in push payloads.
- Auto-follow of default accounts, configurable via environment and dashboard (`newsmast_mastodon:auto_follow` task).
- CiviCRM role assignment API/worker (`CSID_ROLE_ASSIGNMENT_ENABLED`), including the Fellows role.
- Email branding task for header/footer logos (`newsmast_mastodon:email_branding`).
- Task to remove CSID badge fields from accounts.
- Direct-message attachment translations for multiple languages.
- `spec/compatibility/override_manifest_spec.rb`: fails CI when a file installed by `newsmast_mastodon:install` is missing from `config/override_baselines.yml`.

### Changed

- Bumped compatibility contract to Mastodon 4.6.10 (`VERSION = "4.6.10.0"`, `mastodon_version_requirement = "4.6.10"`).
- `NewsmastMastodon::Concerns::DraftStatusService` no longer copies `PostStatusService#call`; draft support is now a set of `super`-calling hooks (`preprocess_attributes!`, `process_status!`, `postprocess_status!`, `bump_potential_friendship!`, `idempotency_duplicate`). Upstream's idempotency lock and duplicate handling now apply to drafts and normal posts.
- Gem CI host-integration default ref is now `patchwork-mastodon-4.6.10`, on Ruby 4.0.9.
- Chewy index overrides (`accounts_index.rb`, `statuses_index.rb`, `public_statuses_index.rb`) are now tracked by the override drift manifest.

### Fixed

- Double-submitting a post with the same `Idempotency-Key` no longer bypasses upstream's redis lock (the gem's `#call` copy predated it), so concurrent requests can no longer create duplicate posts. Picks up upstream fix #40439.
- Repeating a draft request with the same `Idempotency-Key` now returns the existing draft instead of raising `ActiveRecord::RecordNotFound`.
- Drafts silently dropped by Antispam no longer raise `NoMethodError` (`patchwork_drafted_status` typo).
- `bin/rails newsmast_mastodon:install` now runs on a fresh host. The installation guard didn't recognise the task under `bin/rails` because Rails has already consumed `ARGV` by then, so it blocked the very task it asks you to run. It now also checks `Rake.application.top_level_tasks`.
- Admin dashboard/reports: anonymous visitors are redirected to sign-in again instead of getting a 403 from upstream's new admin permission check (GHSA-62j4-hvj7-px3f). Authentication now runs via `prepend_before_action`.
- Long-post character limit handling and auto-update of the max characters in the web UI.
- Signup reason handling in account creation; reblogs scope method name in account statuses filter.
- Favourite/mention handling in `CustomNotificationService`; token management in `FirebaseNotificationService`.

### Security (upstream, verified compatible)

- GHSA-288h-6j8h-6x5j (ActivityPub identifier verification), GHSA-vx32-x96w-qq65 (2FA password bypass for LDAP/PAM/SSO), GHSA-vgm8-frgh-rh2v (JSON-LD DoS), GHSA-62j4-hvj7-px3f (disabled staff admin API access): no gem override shadows the fixed code. See `docs/internal/mastodon-upgrade/reports/report-4.6.10.md`.
- `POST /api/v1/accounts` is now blocked when `SSO_ACCOUNT_SIGN_UP` is set (upstream #40681); the gem's `AccountsCreation#create` override sits behind upstream's `check_enabled_registrations` and inherits this.

## [4.6.5.1] - 2026-08-21

### Changed

- Renamed `NewsmastMastodon::Concerns::MediaAttachmentConcern#local_or_reblogged_status?` to `#locally_authored?` to match its actual behaviour.

### Fixed

- Simplified the alt-text eligibility check in `NewsmastMastodon::Concerns::MediaAttachmentConcern`: removed the redundant `status.reply?` and `status.reblog? && status.account.domain.nil?` branches (both unreachable or already covered by `status.local?`) and made the status lookup nil-safe so alt-text generation no longer raises when the parent status has been deleted.

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
