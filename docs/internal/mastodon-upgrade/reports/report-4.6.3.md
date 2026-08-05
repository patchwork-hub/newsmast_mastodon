# Mastodon Upgrade Report: v4.5.11 → v4.6.3

**Execution Date:** 2026-07-24
**Status:** PHASE C COMPLETE - PHASE D BLOCKED ON STAGING BACKUP

## Release Summary

Upgrade the host Mastodon fork from **v4.5.11** to **v4.6.3** while keeping `newsmast_mastodon` compatible and minimizing fork-specific divergence.

Use this file as the live execution log. Check each box, paste command outputs where requested, and record blockers immediately.

## Release Intake

- **From version:** `4.5.11`
- **Target version:** `4.6.3`
- **Target tag:** `https://github.com/mastodon/mastodon/releases/tag/v4.6.3`
- **Target commit:** `https://github.com/mastodon/mastodon/commit/eeb68053a83894190eefae178a661018b9859494`
- **Base branch:** `patchwork-mastodon-demo-4.5.11-staging`
- **Upgrade branch:** `patchwork-mastodon-demo-4.6.3`
- **Core remote:** `https://github.com/mastodon/mastodon.git`
- **Gem repo:** `https://github.com/patchwork-hub/newsmast_mastodon`
- **Gem dev branch:** `mastodon-4.6.3`
- **Gem release version:** `4.6.3.0`

## Success Criteria

- [ ] Host branch builds and boots on Mastodon 4.6.3.
- [x] Gem compatibility contract and runtime behavior match 4.6.3.
- [ ] Required tests pass (gem + host).
- [ ] Smoke tests pass in staging.
- [ ] Host pin swapped from git branch to exact gem release (`4.6.3.0`).

## Execution Checklist

## Phase 0 - Pre-flight evidence capture

### Pre-flight

- [ ] Confirm clean working tree in both repos. (Not clean; existing changes preserved.)
- [x] Confirm upstream remote points to the official Mastodon repo.
- [ ] Backup staging database before migrations.
- [ ] Confirm the gem compatibility branch exists. (Branch does not exist yet; Phase C will create it.)
- [ ] Confirm environment credentials and services are available.

Commands:

```bash
# host repo
cd /Users/sayamac/workplace/development/patchwork-mastodon(demo)
git status --short
git remote -v | grep upstream

# gem repo
cd /Users/sayamac/workplace/development/newsmast_mastodon(patchwork)
git status --short
git branch --list mastodon-4.6.3
```

Evidence notes:

- Host pre-flight result: On `patchwork-mastodon-demo-4.5.11-staging` at `2fc5976bc3c2c8dd20dee8e6ee1f809888b97955`; existing deletion of `UPGRADE_PLAN.md` preserved. `upstream` fetch/push URL is `https://github.com/mastodon/mastodon.git`. Upgrade branch was not present.
- Gem pre-flight result: On `main` at `4d4caa5ef807c0bc4f0c20efa0cef9acc4e0a615`; existing modified/untracked documentation changes preserved. `mastodon-4.6.3` was not present locally.
- Staging DB backup reference: Not available from the local environment; must be recorded before Phase D migrations.
- Credentials/services: Not yet verified; boot and integration commands will provide local evidence, but staging credentials require operator confirmation.

## Phase A - Host branch and fetch

- [x] Create the host upgrade branch from the selected base branch.
- [x] Fetch upstream tags and refs.

Commands:

```bash
cd /Users/sayamac/workplace/development/patchwork-mastodon(demo)
git checkout patchwork-mastodon-demo-4.5.11-staging
git checkout -b patchwork-mastodon-demo-4.6.3
git fetch upstream --tags
```

Evidence notes:

- Branch created at commit: `2fc5976bc3c2c8dd20dee8e6ee1f809888b97955` (`patchwork-mastodon-demo-4.5.11-staging` HEAD).
- Target upstream tag verified: `v4.6.3` resolves to `eeb68053a83894190eefae178a661018b9859494`, matching the release intake.
- Fetch result: Official upstream refs and tags fetched successfully on 2026-07-24.

## Phase B - Host merge v4.6.3

- [x] Merge the v4.6.3 tag with `--no-commit --no-ff`.
- [x] Resolve conflicts and regenerate `CONFLICT_CHECKLIST.md`.
- [x] Confirm `lib/mastodon/version.rb` reports `4.6.3`.
- [x] Commit the merge.

Commands:

```bash
cd /Users/sayamac/workplace/development/patchwork-mastodon(demo)
git merge v4.6.3 --no-commit --no-ff

# after conflict resolution
git status
git add -A
git commit -m "Merge upstream Mastodon v4.6.3"
```

Evidence notes:

- Merge conflicts encountered: Initial three-way merge reported 185 textual conflicts because the fork and target diverged at `2a9c7d2b9e51cdfbc636972c0f9ffdbe06c02d59`. Reconstructing the result as pristine `v4.6.3` plus the exact committed fork delta from `v4.5.11` reduced this to nine genuine overlaps: `Dockerfile`, `Gemfile`, `Gemfile.lock`, `app/chewy/public_statuses_index.rb`, `app/javascript/mastodon/actions/compose.js`, `app/models/account.rb`, `app/models/media_attachment.rb`, `app/models/status.rb`, and `db/schema.rb`.
- Conflict resolution summary: Preserved Mastodon 4.6.3 architecture and dependency baseline while replaying custom timelines, local-only posts, banned-content scopes, draft media, custom schema tables/columns, AWS CLI support, and vendored UI overrides. Preserved the pre-flight deletion of the superseded `UPGRADE_PLAN.md`. Regenerated `CONFLICT_CHECKLIST.md` with 34 upstream migrations, dependency changes, collision evidence, and override drift risks. Final staged validation: zero unresolved paths and `git diff --cached --check` passed.
- Version verification: `lib/mastodon/version.rb` contains major `4`, minor `6`, patch `3`.
- Merge commit SHA: `f7f7ffbfb55921fd0e4348699126fa5d0b61202e` (parents: base `2fc5976bc3c2c8dd20dee8e6ee1f809888b97955`, target `eeb68053a83894190eefae178a661018b9859494`). Commit is local and has not been pushed.

## Phase C - Gem compatibility work

- [x] Create or update the `mastodon-4.6.3` gem branch.
- [x] Update the compatibility contract in the gem.
- [x] Update any patched concerns or services for upstream API changes.
- [x] Move fork-specific Chewy index scope changes into the gem so hosts keep upstream Chewy files verbatim.
- [x] Guard gem migrations for column/table existence.
- [x] Point the host Gemfile at the gem dev branch temporarily.

Commands:

```bash
cd /Users/sayamac/workplace/development/newsmast_mastodon(patchwork)
git checkout main
git pull --ff-only
git checkout -b mastodon-4.6.3

# run compatibility safety specs
bundle exec rspec spec/compatibility/version_sync_spec.rb
bundle exec rspec spec/compatibility/migration_guard_spec.rb
```

Temporary host wiring:

```ruby
gem "newsmast_mastodon",
 git: "https://github.com/patchwork-hub/newsmast_mastodon",
 branch: "mastodon-4.6.3"
```

Evidence notes:

- Gem branch: Created locally from `main` at `4d4caa5ef807c0bc4f0c20efa0cef9acc4e0a615`. Latest local commit `6acaf45`. The branch has not been pushed.
- Gem contract updates completed: Release version `4.6.3.0`; `mastodon_version_requirement` `4.6.3`; Rails `~> 8.1.0`; Ruby `>= 3.3.0, < 4.1.0`; development Sidekiq `~> 8.1.0`; CI matrix Ruby 3.3, 3.4, and 4.0.
- Upstream API compatibility: `NotifyServiceExtension#call` now accepts and forwards keyword options used by Mastodon 4.6.3. The focused `silenced:` regression spec passed.
- Chewy index overrides: The engine's `NewsmastMastodon::AccountsIndex`, `NewsmastMastodon::StatusesIndex`, and `NewsmastMastodon::PublicStatusesIndex` now declare explicit upstream `index_name` values and replace the host constants at boot time. The host fork's inline `without_banned` customizations in `app/chewy/{accounts,statuses,public_statuses}_index.rb` were removed so downstream hosts can use vanilla Mastodon Chewy files. Documentation added to `README.md`, `docs/internal/peer-dependencies.md`, and `docs/internal/mastodon-upgrade/RUNBOOK.md`.
- Vendored frontend overrides: Four changed sources were rebased to the reviewed Mastodon 4.6.3 host versions. `bin/check-override-drift` passed all five tracked overrides after baseline refresh.
- Dependency result: `RBENV_VERSION=4.0.5 bundle install` completed with Rails 8.1.3 and Sidekiq 8.1.6. The only warning was a non-fatal rbenv rehash failure after bundle completion.
- Consolidated safety specs (including Chewy override host-integration tests): `RBENV_VERSION=4.0.5 bundle exec rspec spec/compatibility/version_sync_spec.rb spec/compatibility/migration_guard_spec.rb spec/services/newsmast_mastodon/notify_service_extension_spec.rb spec/integration/prepend_concerns_spec.rb` passed: 85 examples, 0 failures, 7 pending host-integration examples.
- Full standalone suite: `RBENV_VERSION=4.0.5 bundle exec rspec` passed: 342 examples, 0 failures, 96 expected pending host-integration examples.
- Focused lint and diagnostics: RuboCop passed all five changed Ruby files; VS Code reported no diagnostics in the changed workflow, Ruby, JavaScript, JSX, or TypeScript files; `git diff --check` passed.
- Host Gemfile temporary wiring commit SHA: `f7f7ffbfb55921fd0e4348699126fa5d0b61202e` (local only). Host Chewy cleanup commit SHA: `47baadb20c` (local only). The git branch dependency cannot be installed in the host until `mastodon-4.6.3` is available to the host dependency resolver; no push was performed.
- Phase D blocker: No staging-clone database backup reference is available. Do not run migrations until an operator records and verifies the backup.

## Phase D - Database and boot validation

- [ ] Apply migrations against a staging clone.
- [ ] Verify migration idempotency for any overlapping columns.
- [ ] Install gem-shipped indexes and overrides.
- [ ] Boot the app and verify `Mastodon::Version`.

Commands:

```bash
cd /Users/sayamac/workplace/development/patchwork-mastodon(demo)
bin/rails db:migrate
bin/rails newsmast_mastodon:install
yarn build:development
bin/rails runner 'puts Mastodon::Version.to_s'
```

Check overlap explicitly:

- `status_edits.quote_id`
- `statuses.fetched_replies_at`
- `statuses.local_only`
- `announcements.notification_sent_at`

Evidence notes:

- Migration output summary:
- Version output:
- Any migration guards added:

## Phase E - Verification gates

- [ ] Run gem specs.
- [ ] Run host-core specs.
- [ ] Run override drift checks.
- [ ] Run manual smoke tests.

Commands:

```bash
# gem standalone
cd /Users/sayamac/workplace/development/newsmast_mastodon(patchwork)
bundle exec rspec

# gem against upgraded host
MASTODON_ROOT=/Users/sayamac/workplace/development/patchwork-mastodon(demo) bundle exec rspec

# override drift
bin/check-override-drift /Users/sayamac/workplace/development/patchwork-mastodon(demo)

# host core suite
cd /Users/sayamac/workplace/development/patchwork-mastodon(demo)
bundle exec rspec
```

Manual smoke checklist:

- [ ] Login/session
- [ ] OAuth token issuance
- [ ] Password change/reset
- [ ] Post create/edit/draft
- [ ] Local-only posts
- [ ] Custom feeds/timelines
- [ ] Banned-keyword filtering
- [ ] Admin dashboard/auth
- [ ] Deep links (`apple-app-site-association`, `assetlinks.json`)

Evidence notes:

- Gem spec result:
- Host spec result:
- Drift check result:
- Smoke test notes:

## Phase RELEASE - Gem release

- [ ] Merge `mastodon-4.6.3` into `main` on green CI.
- [ ] Tag and publish `v4.6.3.0`.
- [ ] Confirm `4.6.3.0` is available on RubyGems.

Commands:

```bash
cd /Users/sayamac/workplace/development/newsmast_mastodon(patchwork)
git checkout main
git pull --ff-only
git tag -s v4.6.3.0 -m "Release v4.6.3.0"
git push origin v4.6.3.0
```

Evidence notes:

- Release tag SHA:
- RubyGems verification output:

## Phase F - Host exact pin and staging ship

- [ ] Replace temporary branch source with exact pin `gem "newsmast_mastodon", "4.6.3.0"`.
- [ ] `bundle install` and commit lockfile changes.
- [ ] Deploy staging and re-run smoke checklist.
- [ ] Record go/no-go.

Evidence notes:

- Host pin commit SHA:
- Staging deploy reference:
- Go/no-go decision:

## Phase G - Production

- [ ] Deploy production branch after staging pass.
- [ ] Record deployment time and incidents.

Evidence notes:

- Production deploy reference:
- Incident notes:

## Risk Notes (4.6.3)

- Review auth/session stack changes introduced by 4.6.3.
- Check any upstream changes that affect prepended concerns, migrations, or vendored frontend overrides.
- Record incompatibilities in the gem branch before release and host pinning.

## Final Outcome

- **Go / No-go:** pending
- **Host merge commit SHA:** pending
- **Gem release tag:** pending
- **Gem test result:** pending
- **Core test result:** pending
- **Smoke test result:** pending
- **Known follow-ups:** pending
