# Newsmast Mastodon v4.6.3 Release Notes

## Upgrade Overview

This release upgrades Newsmast Mastodon to track **Mastodon 4.6.3** and includes several enhancements, governance improvements, and bug fixes.

**Special notes for upgrading:**

- **Database migrations** – New migrations included for status reactions and account profile fields. Standard Rails migration process applies.
- **Ruby version requirement** – Now requires Ruby 3.3 or 3.4; Ruby 3.1 and 3.2 are no longer supported.
- **Rails 8.1 compatibility** – Upgraded to Rails ~> 8.1.0 and Sidekiq ~> 8.1.0.
- **No breaking changes** – All changes are backward compatible within the supported version range.
- **Rebuild recommended** – If using compiled assets, rebuild with `bundle exec rails assets:precompile` after upgrading.

---

## Changelog

### Security

No security vulnerabilities addressed in this release. For reporting security issues, see [SECURITY.md](SECURITY.md).

### Added

- **Governance & Documentation**
  - Added [GOVERNANCE.md](GOVERNANCE.md) documenting decision, merge, and release policy
  - Added [MAINTAINERS.md](MAINTAINERS.md) to document ownership and review responsibilities
  - Added [SUPPORT.md](SUPPORT.md) with support routing and response expectations
  - Added `docs/internal/peer-dependencies.md` documenting gems supplied by the host Mastodon application and the engine's own runtime dependencies
  - Added per-directory provenance records under `config/data/*/PROVENANCE.md`
  - Added [NOTICE](NOTICE) with license and dependency attribution guidance

- **Operational Tools**
  - Added `newsmast_mastodon:backfill_csid_badge_fields` rake task to populate blank account profile fields from CSID CiviCRM membership groups, with `DRY_RUN`, `BATCH_SIZE`, and `EMAIL` targeting support ([db63915](https://github.com/patchwork-hub/newsmast_mastodon/commit/db63915))

- **Dependencies**
  - Added runtime dependencies `jwt`, `faraday`, and `parslet` to `newsmast_mastodon.gemspec`, pinned to compatible versions matching Mastodon 4.6.3

### Changed

- **Dependency Alignment** ([db63915](https://github.com/patchwork-hub/newsmast_mastodon/commit/db63915))
  - Aligned `newsmast_mastodon.gemspec` with Mastodon 4.6.3:
    - Rails `~> 8.1.0`
    - Ruby `>= 3.3.0, < 4.1.0`
    - Sidekiq `~> 8.1.0` (development)
    - All runtime dependencies aligned with host Mastodon version

- **CI/CD & Release Workflows**
  - Refactored CI workflows to use shared runtime setup action and added per-job timeouts
  - Introduced `ci-ok` as a stable aggregate required check
  - Hardened release workflow with checksum generation and build provenance attestation
  - Added `no-changelog` PR label bypass support to `changelog-policy` for approved non-behavioral changes
  - Grouped Dependabot major updates for Bundler and GitHub Actions to reduce noise
  - Hardened release gating with protected `rubygems` environment and ancestry verification
  - Expanded security automation with `bundler-audit`, `actionlint`, and `zizmor`

- **Ruby Version Support** ([9a73b5a](https://github.com/patchwork-hub/newsmast_mastodon/commit/9a73b5a))
  - **Dropped end-of-life Ruby 3.1** from CI and support; CI now covers Ruby 3.2, 3.3, and 3.4
  - Updated documentation with new CI coverage guidelines

- **CiviCRM Integration** ([db63915](https://github.com/patchwork-hub/newsmast_mastodon/commit/db63915))
  - Updated CSID signup flow to persist up to four `CSID Badge` account fields from CiviCRM `user_groups` (excluding `Newsletter sign-up`) during account creation
  - Expanded `NewsmastMastodon::CivicrmMembershipCheckService`:
    - Now returns extracted `user_groups`
    - Supports `force_remote:` checks
    - Handles multiple CiviCRM response shapes more robustly

- **Notification Handling** ([db63915](https://github.com/patchwork-hub/newsmast_mastodon/commit/db63915))
  - Adjusted mention notification copy selection in `CustomNotificationService` to account for notification request presence with direct/public visibility

- **Documentation Updates**
  - Expanded [CONTRIBUTING.md](CONTRIBUTING.md) with versioning, breaking-change, and release guidance
  - Aligned `CONTRIBUTING.md` release checklist with checksum and provenance attestation workflow steps
  - Added community/governance/support links to [README.md](README.md)
  - Linked non-security conduct reporting path from [SECURITY.md](SECURITY.md)
  - Cross-linked governance, maintainer, and support documents for easier navigation

### Fixed

- **Database Schema** ([db63915](https://github.com/patchwork-hub/newsmast_mastodon/commit/db63915))
  - Fixed `spec/dummy/db/schema.rb` declaring `ActiveRecord::Schema[8.1]`, which broke Postgres-backed specs under Rails 8.0 by causing `maintain_test_schema\!` to abort and leave bootstrap tables unreachable

- **Status Creation & Domain Handling** ([fa3171b](https://github.com/patchwork-hub/newsmast_mastodon/commit/fa3171b), [4db7351](https://github.com/patchwork-hub/newsmast_mastodon/commit/4db7351))
  - Improved logging in `create_status` method to include author domain information
  - Fixed author domain retrieval in `create_status` method to handle nil status cases

- **Account Creation** ([afec7fa](https://github.com/patchwork-hub/newsmast_mastodon/commit/afec7fa))
  - Fixed response body serialization in accounts creation endpoint

- **Database Resilience** ([e7f0b46](https://github.com/patchwork-hub/newsmast_mastodon/commit/e7f0b46))
  - Handle database connection errors gracefully in `UserConcern` methods with updated test coverage

- **Migrations** ([5da0ad2](https://github.com/patchwork-hub/newsmast_mastodon/commit/5da0ad2))
  - Added conditional checks to index and foreign key definitions in `patchwork_status_reactions` migration to prevent errors on re-runs

- **Installation Guard** ([a9c2e0b](https://github.com/patchwork-hub/newsmast_mastodon/commit/a9c2e0b))
  - Implemented installation guard for Newsmast Mastodon gem to prevent issues in non-Newsmast installations

- **Chewy Integration** ([9bfd72e](https://github.com/patchwork-hub/newsmast_mastodon/commit/9bfd72e))
  - Added Chewy autoload exclusion initializer to prevent unwanted autoloading

- **Tag Normalization** ([23172e0](https://github.com/patchwork-hub/newsmast_mastodon/commit/23172e0))
  - Refactored tag normalization methods in `TagConcern` for consistency

---

## Upgrade Instructions

### Prerequisites

Before upgrading, ensure:

- You are currently running Newsmast Mastodon **v4.5.11** or later
- Your system has **Ruby 3.3 or 3.4** installed (3.2 is no longer supported)
- You have **Rails 8.1** compatible with Mastodon 4.6.3
- You have a **recent backup** of your database and media storage

### Step-by-Step Upgrade

#### 1. Backup Your Database and Media

```bash
# Create a backup of your database
pg_dump -Fc mastodon_production > ~/mastodon_backup_$(date +%Y%m%d_%H%M%S).dump

# Backup media directory (optional but recommended)
tar czf ~/mastodon_media_backup_$(date +%Y%m%d_%H%M%S).tar.gz /var/lib/mastodon/public/system
```

#### 2. Update the Repository

```bash
cd /path/to/newsmast_mastodon
git fetch origin
git checkout v4.6.3  # or git checkout mastodon-4.6.3
```

#### 3. Install Dependencies

```bash
bundle install --deployment --without development:test
yarn install --frozen-lockfile
```

#### 4. Run Database Migrations

```bash
RAILS_ENV=production bundle exec rails db:migrate
```

#### 5. Recompile Assets (if using pre-compiled assets)

```bash
RAILS_ENV=production bundle exec rails assets:precompile
```

#### 6. Restart Services

```bash
# Restart Puma
systemctl restart mastodon-web

# Restart Sidekiq
systemctl restart mastodon-sidekiq

# Restart Streaming API (if running separately)
systemctl restart mastodon-streaming
```

#### 7. Verify the Upgrade

```bash
# Check Rails version
RAILS_ENV=production bundle exec rails --version

# Verify gem version
RAILS_ENV=production bundle exec rails -e production -c 'puts NewsmastMastodon::VERSION'

# Check logs for errors
tail -f /var/log/mastodon/production.log
```

### Post-Upgrade Tasks

- Review [CHANGELOG.md](CHANGELOG.md) for the full list of changes
- Update your deployment documentation with Ruby 3.3+ as the minimum requirement
- If using CiviCRM integration, test the new CSID badge field population using the provided rake task (with `DRY_RUN=true` first):

  ```bash
  RAILS_ENV=production DRY_RUN=true bundle exec rails newsmast_mastodon:backfill_csid_badge_fields
  ```

### Rollback Plan

If you encounter issues during the upgrade:

```bash
# Restore the previous backup
git checkout v4.5.11
bundle install --deployment --without development:test

# Restore the database from backup
pg_restore -d mastodon_production < ~/mastodon_backup_YYYYMMDD_HHMMSS.dump

# Restart services
systemctl restart mastodon-web mastodon-sidekiq
```

---

## Support & Issues

For support:

- **Documentation**: See [SUPPORT.md](SUPPORT.md) for routing and response expectations
- **Governance**: See [GOVERNANCE.md](GOVERNANCE.md) for decision and release policy
- **Contributing**: See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines
- **Security Issues**: See [SECURITY.md](SECURITY.md) for responsible disclosure

---

## Contributors

This release includes contributions from the Newsmast Mastodon and Patchwork Hub teams. See [MAINTAINERS.md](MAINTAINERS.md) and commit history for full attribution.
