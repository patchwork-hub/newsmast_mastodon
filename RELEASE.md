# Newsmast Mastodon v4.6.5.0 Release Notes

## Upgrade Overview

This release moves the compatibility contract from **Mastodon 4.6.3** to **Mastodon 4.6.5**. Mastodon 4.6.5 is a bug-fix release, and the gem changes are limited to keeping its overrides in step with upstream.

**Special notes for upgrading:**

- **No new migrations.** Neither upstream (v4.6.3 → v4.6.5) nor the gem adds migrations in this release.
- **Ruby and Rails unchanged.** Still Ruby `>= 3.3.0, < 4.1.0` and Rails `~> 8.1.0`.
- **Host branch.** The host is now a clean upstream snapshot (`patchwork-mastodon-4.6.5`), with every Patchwork/Newsmast customization shipped through this gem.
- **Rebuild frontend assets.** Frontend overrides were rebased onto v4.6.5.

For the full upgrade record, see [`docs/internal/mastodon-upgrade/reports/report-4.6.5.md`](docs/internal/mastodon-upgrade/reports/report-4.6.5.md).

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the authoritative entry list.

### Changed

- Bumped the compatibility contract to Mastodon 4.6.5 (`VERSION = "4.6.5.0"`, `mastodon_version_requirement = "4.6.5"`).
- `PostStatusService#postprocess_status!` override now includes upstream's new `process_email_subscriptions!` step. The gem's local-only ActivityPub guard and the `BanStatusWorker` hook are kept.
- Rebased frontend/view overrides onto v4.6.5 and refreshed their drift baselines.
- Formatted the Chewy index overrides (`app/chewy/newsmast_mastodon/*.rb`) to the host's RuboCop style.

### Added

- Added `app/javascript/mastodon/features/compose/containers/compose_form_container.js` to the frontend override drift manifest.
- Added the Mastodon 4.6.5 upgrade report and runbook tracking.

---

## Upgrade Instructions

### Prerequisites

- The host runs Mastodon **4.6.5**.
- You are on `newsmast_mastodon` **4.6.3.x**.
- You have a recent backup of the database and media storage.

### Steps

1. Pin the gem in the host `Gemfile`, then install:

   ```ruby
   gem "newsmast_mastodon", "4.6.5.0"
   ```

   ```bash
   bundle install
   ```

2. Install the gem's overrides and indexes, and run migrations. There are no new migrations, but running it confirms the schema is current:

   ```bash
   RAILS_ENV=production bin/rake newsmast_mastodon:install
   RAILS_ENV=production bin/rails db:migrate
   ```

3. Rebuild assets:

   ```bash
   RAILS_ENV=production bin/rails assets:precompile
   ```

4. Restart web, Sidekiq and streaming.

5. Verify:

   ```bash
   RAILS_ENV=production bin/rails runner 'puts Mastodon::Version.to_s; puts NewsmastMastodon::VERSION'
   ```

### Rollback

Re-pin the host `Gemfile` to the last known-good gem version (`4.6.3.x`), point the deploy back at the previous host branch, and redeploy. No database rollback is needed, because this release adds no migrations.

---

## Support & Issues

- **Support**: [SUPPORT.md](SUPPORT.md)
- **Governance**: [GOVERNANCE.md](GOVERNANCE.md)
- **Contributing**: [CONTRIBUTING.md](CONTRIBUTING.md)
- **Security issues**: [SECURITY.md](SECURITY.md)
