# Mastodon Upgrade Report: v4.6.3 → v4.6.5

**Execution Date:** 2026-08-10  
**Status:** PHASE C IN PROGRESS — gem compatibility branch prepared, host snapshot branch created, override/Chewy rebase complete

## Release Summary

Upgrade the host Mastodon snapshot from **v4.6.3** to **v4.6.5** while keeping `newsmast_mastodon` compatible. This cycle adopts the new clean-upstream-snapshot workflow: the host branch is created directly from the upstream release tag and all Patchwork/Newsmast customization ships via the engine gem.

## Release Intake

- **From version:** `4.6.3`
- **Target version:** `4.6.5`
- **Target tag:** `https://github.com/mastodon/mastodon/releases/tag/v4.6.5`
- **Target commit:** `1440d55b13`
- **Base branch:** `patchwork-mastodon-demo-4.6.3`
- **Upgrade branch:** `patchwork-mastodon-4.6.5`
- **Core remote:** `https://github.com/mastodon/mastodon.git`
- **Gem repo:** `https://github.com/patchwork-hub/newsmast_mastodon`
- **Gem dev branch:** `mastodon-4.6.5`
- **Gem release version:** `4.6.5.0`
- **Host modification policy:** no Patchwork-specific commits in `patchwork-mastodon`; all customization ships via `newsmast_mastodon`

## What was collected for this release

- **Release-notes delta:** bug-fix release between v4.6.3 and v4.6.5. 48 commits. Key areas:
  - ActivityPub inbound processing (`ActivityPub::Activity::Create`, collection/quote handling, relevancy checks)
  - Account merging and suspension (`Account::Merging`, `ASSOCIATIONS_ON_PURGE`)
  - Status update / quote post editing (`ProcessStatusUpdateService`)
  - Web Push subscription CSRF fix, admin dashboard query performance, media upload limits
  - UI: emoji search, poll voting without expiration, custom profile fields, quote-post CW handling
- **Core migrations in range:** none (`git diff --name-only v4.6.3..v4.6.5 -- db/migrate` returned empty).
- **Major dependency jumps:** only lockfile bumps in the upstream range:
  - `aws-sdk-s3`
  - `@vitest/browser` 4.1.10 (security)
  - `rails-html-sanitizer`
  - `websocket-driver`
  - `json`
- **API/signature changes that may affect gem concerns:**
  - `ActivityPub::Activity::Create` logic around recreating known statuses and relevancy checks.
  - `Account::Merging` refactor and `ASSOCIATIONS_ON_SUSPEND` → `ASSOCIATIONS_ON_PURGE` rename.
  - `ProcessStatusUpdateService` media-attachment limit fix and quote-edit handling.
- **Vendored frontend/view drift:** all 6 tracked upstream override files changed between v4.6.3 and v4.6.5 and have been rebased.
- **Estimated risk summary:** low-to-medium. No new migrations reduces schema risk, but several upstream bug-fixes touch code paths that the gem prepends or includes into (`Create`, status services, account merging). The manual smoke checklist and full spec runs are the main remaining gates.

## Success Criteria

- [ ] Host branch builds and boots on Mastodon 4.6.5.
- [x] Gem compatibility contract updated to 4.6.5.
- [x] Vendored frontend overrides rebased to v4.6.5 and drift check passes.
- [x] Chewy index overrides remain compatible with v4.6.5.
- [ ] Required tests pass (gem standalone + against upgraded host).
- [ ] Smoke tests pass in staging.
- [ ] Host pin swapped from git branch to exact gem release (`4.6.5.0`).

## Execution Checklist

### Phase 0 — Pre-flight

- [x] Clean working tree in the gem repo (after stashing/popping the in-progress runbook/baseline edits onto the new branch).
- [x] `upstream` remote on the host points to the official Mastodon repo.
- [ ] Backup the staging database before migrations.
- [ ] Credentials/env available for boot, migration, and test runs in both repos.
- [ ] Gem CI is green on `main` before starting.
- [ ] DevOps confirms deployment configuration for target stage is ready.

Evidence notes:

- Gem repo: on `mastodon-4.6.5` (created from `mastodon-4.6.3` to preserve the merged `csid_role_assignment` work). Uncommitted changes are the intended contract/runbook/baseline updates.
- Host repo: on `patchwork-mastodon-4.6.5`, created from `v4.6.5` (`1440d55b13`). Working tree is clean.
- `upstream` fetch/push URL is `https://github.com/mastodon/mastodon.git`.
- Upstream tag `v4.6.5` fetched successfully.

### Phase A-B — Create host snapshot branch

- [x] Fetch upstream tags.
- [x] Create `patchwork-mastodon-4.6.5` from `v4.6.5`.
- [x] Confirm `lib/mastodon/version.rb` reports `4.6.5`.
- [x] Confirm `git log --oneline -1` shows the upstream release commit.
- [x] Confirm working tree is clean.
- [x] `CONFLICT_CHECKLIST.md` is not present (old merge workflow artifact removed).

Commands:

```bash
cd /Users/sayamac/workplace/development/patchwork-mastodon(demo)
git fetch upstream --tags
git checkout -b patchwork-mastodon-4.6.5 v4.6.5
```

Evidence notes:

- Host branch created at upstream commit `1440d55b13` (`Bump version to v4.6.5`).
- `lib/mastodon/version.rb` patch value is `5` (major 4, minor 6, patch 5).
- Working tree clean.

### Phase C — Gem changes & temporary wiring

- [x] Create `mastodon-4.6.5` gem branch.
- [x] Update compatibility contract:
  - `lib/newsmast_mastodon/version.rb` → `VERSION = "4.6.5.0"`
  - `newsmast_mastodon.gemspec` → `mastodon_version_requirement = "4.6.5"`
  - `README.md` compatibility examples updated
  - `CHANGELOG.md` new `[4.6.5.0]` section added
- [x] Run `spec/compatibility/version_sync_spec.rb` — passed.
- [x] Run `spec/compatibility/migration_guard_spec.rb` — passed.
- [ ] Review and update patched concerns/services for upstream API changes.
- [x] Chewy index overrides verified compatible with v4.6.5 (no upstream changes in `app/chewy/` between v4.6.3 and v4.6.5).
- [x] Frontend/view overrides rebased to v4.6.5 and baselines refreshed.
- [ ] Temporarily point host Gemfile at gem dev branch and `bundle install`.

Commands:

```bash
cd /Users/sayamac/workplace/development/newsmast_mastodon(patchwork)
bundle exec rspec spec/compatibility/version_sync_spec.rb
bundle exec rspec spec/compatibility/migration_guard_spec.rb
bin/check-override-drift /Users/sayamac/workplace/development/patchwork-mastodon\(demo\)
```

Evidence notes:

- Version/sync and migration-guard specs: 77 examples, 0 failures.
- Drift check: `No override drift: all 6 upstream override(s) match recorded baselines.`
- Rebased files:
  - `app/javascript/mastodon/actions/compose.js`
  - `app/javascript/mastodon/reducers/compose.js`
  - `app/javascript/mastodon/features/compose/components/compose_form.jsx`
  - `app/javascript/mastodon/features/compose/containers/compose_form_container.js`
  - `app/javascript/mastodon/features/status/components/detailed_status.tsx`
  - `app/views/admin/shared/_status.html.haml`
- `compose_form_container.js` was newly added to the drift manifest this cycle.

### Phase D — Database and boot (host)

- [ ] Apply migrations against a staging clone.
- [ ] Verify migration idempotency for overlapping columns:
  - `status_edits.quote_id`
  - `statuses.fetched_replies_at`
  - `statuses.local_only`
  - `announcements.notification_sent_at`
- [ ] Install gem-shipped indexes and overrides (`bin/rails newsmast_mastodon:install`).
- [ ] Rebuild frontend assets.
- [ ] Boot the app and verify `Mastodon::Version`.

### Phase E — Verification gates

- [ ] Run gem standalone specs.
- [ ] Run gem specs against upgraded host (`MASTODON_ROOT=... bundle exec rspec`).
- [ ] Run host core specs.
- [ ] Manual smoke checklist:
  - [ ] Login / session
  - [ ] OAuth token issuance (Doorkeeper password grant)
  - [ ] Password change / reset flow
  - [ ] Post create / edit / draft flow
  - [ ] Local-only post behavior
  - [ ] Custom feeds / timelines
  - [ ] Banned-keyword filtering
  - [ ] Admin authentication / dashboard
  - [ ] Deep links (`apple-app-site-association`, `assetlinks.json`)
- [ ] Classify any failure.

### Phase RELEASE — Publish the gem

- [ ] Open PR `mastodon-4.6.5` → `main`; require green CI.
- [ ] Merge and tag `v4.6.5.0`.
- [ ] Confirm gem live on RubyGems.

### Phase F — Pin & ship to staging

- [ ] Replace temporary branch source with exact pin `gem "newsmast_mastodon", "4.6.5.0"`.
- [ ] Commit, push `patchwork-mastodon-4.6.5`, deploy staging.
- [ ] Re-run smoke checklist in staging.
- [ ] Record go/no-go decision.

### Phase G — Production

- [ ] Deploy production once staging passes.
- [ ] Record deployment time and any issues.

## Rollback

- [ ] Abandon `patchwork-mastodon-4.6.5` if blocked.
- [ ] Restore database from pre-migration backup.
- [ ] Re-pin host Gemfile to last known-good gem version.
- [ ] Re-point deploy configuration to last known-good branch/tag.
