# Internal Runbook — Upgrading `newsmast_mastodon` for a New Mastodon Version

> **Audience: internal maintainers only.** This is for the team that develops
> and releases the `newsmast_mastodon` engine gem. It is **not** a guide for
> downstream consumers upgrading the gem dependency in their own app.

This is the single source of truth for upgrading the host Mastodon snapshot
(`patchwork-mastodon`) together with the `newsmast_mastodon` engine gem.

> **Why this lives in the gem repo:** the gem defines the compatibility
> contract (`mastodon_version_requirement` metadata, shipped migrations,
> prepended concerns, vendored frontend overrides). The host app only *consumes*
> a released, version-pinned gem. Keeping the runbook next to the contract it
> describes prevents the two from drifting apart.

> **Host modification policy:** `patchwork-mastodon` is treated as an
> unmodified upstream snapshot. All Patchwork/Newsmast customization lives in
> the engine gem. The host upgrade branch is created directly from the upstream
> release tag; no Patchwork-specific commits are made in the host repo.
> Deployment configuration is managed by DevOps outside this repository.
>
> **How the gem modifies the host without host commits:** A Rails engine gem
> injects its behavior into the host app at runtime. Migrations ship from
> `newsmast_mastodon/db/migrate/` and are applied by `bin/rails db:migrate`.
> Chewy index overrides, prepended concerns, and services are loaded at boot
> via `config/initializers/prepend_concerns.rb` and `lib/newsmast_mastodon/engine.rb`.
> Frontend and view overrides are copied into the host tree by
> `bin/rails newsmast_mastodon:install`. Downstream consumers who add the gem
> to their own Mastodon host receive the same modifications automatically.

## How to use this document

1. Copy the **Release intake** block into a new file under
   [`reports/`](./reports/) named `report-<TO_VERSION>.md`.
2. Fill the intake values for the cycle.
3. Work top-to-bottom through the phases, checking items off in your report copy.
4. Leave this template unfilled — it is reused every cycle.

---

## Dependency model (canonical)

The host app pins an **exact, released gem version** — never a floating
constraint and never a long-lived git branch in production:

```ruby
# patchwork-mastodon/Gemfile
gem "newsmast_mastodon", "X.Y.Z.N"
```

A git `branch:` source is permitted **only** during active upgrade development
(Phase C). It must be replaced with an exact version pin before staging
(Phase F). This matches the gem `README.md` policy and avoids unplanned
compatibility drift.

Because the host repo is an unmodified upstream snapshot, the gem is the
**only** source of Patchwork/Newsmast code that reaches the host. No
customization is committed to `patchwork-mastodon`.

## Branch & tag naming (canonical)

| Repo                 | Purpose            | Pattern                      | Example                      |
| -------------------- | ------------------ | ---------------------------- | ---------------------------- |
| `newsmast_mastodon`  | upgrade dev branch | `mastodon-X.Y.Z`             | `mastodon-4.5.12`            |
| `newsmast_mastodon`  | release tag        | `vX.Y.Z.N`                   | `v4.5.12.0`                  |
| `patchwork-mastodon` | upgrade branch     | `csidnet-X.Y.Z`              | `csidnet-4.5.12`             |
| `patchwork-mastodon` | deploy branch      | `csidnet-X.Y.Z-<stage>`      | `csidnet-4.5.12-production`  |

The `patchwork-mastodon` upgrade branch is a **clean upstream snapshot**
created from `v<TO_VERSION>`. It contains no Patchwork-specific commits.

Do not introduce ad-hoc suffixes (e.g. `mastodon-4512-signup`); feature work
belongs on short-lived branches that merge into `mastodon-X.Y.Z` before release.

---

## Release intake (fill before starting — copy into your report)

```
FROM_VERSION:   4.6.3
TO_VERSION:     4.6.5
TARGET_TAG:     https://github.com/mastodon/mastodon/releases/tag/v4.6.5
BASE_BRANCH:    patchwork-mastodon-demo-4.6.3
UPGRADE_BRANCH: patchwork-mastodon-4.6.5
CORE_REMOTE:    https://github.com/mastodon/mastodon.git
GEM_REPO:       https://github.com/patchwork-hub/newsmast_mastodon
GEM_DEV_BRANCH: mastodon-4.6.5
GEM_VERSION:    4.6.5.0 # released gem version pinned by the host
HOST_MODIFICATION_POLICY: no Patchwork-specific commits in patchwork-mastodon;
                          all customization ships via newsmast_mastodon
```

## What to collect for each release

- [ ] Release-notes delta for `FROM_VERSION -> TO_VERSION`.
- [ ] Count and names of upstream core migrations introduced in the range.
- [ ] Major dependency jumps (especially the auth/session stack).
- [ ] API/signature changes that may affect prepended/included concerns.
- [ ] Upstream changes to any file the gem **vendors** (see Phase E drift check).
- [ ] Estimated risk summary for this cycle.

---

## Coordinated release sequence (read first)

The upgrade spans two repos and must happen in this order:

```mermaid
flowchart TD
    A[Phase A-B: host creates clean branch from upstream tag] --> B[Phase C: gem dev branch + host points at branch]
    B --> C[Phase D-E: migrate, boot, verify, drift check]
   C --> D[Phase RELEASE: tag & publish gem vX.Y.Z.N to RubyGems]
    D --> E[Phase F: host swaps branch -> exact version pin, ship to staging]
    E --> F[Phase G: production]
```

The gem is **released first**; the host then pins the released version. Never
ship a host deploy that points at a git branch.

---

## Pre-flight

- [ ] Clean working tree in both repos: `git status`.
- [ ] `upstream` remote on the host matches `CORE_REMOTE`.
- [ ] Backup the staging database before any migration.
- [ ] Credentials/env available for boot, migration, and test runs in both repos.
- [ ] Gem CI is green on `main` before starting.
- [ ] Confirm with DevOps that deployment configuration for the target stage
      is ready and will be injected outside this repository.

## Phase A-B — Create host snapshot branch (host)

The host upgrade branch is created directly from the upstream release tag.
No merge is performed and no Patchwork-specific commits are added to the host.

```bash
cd patchwork-mastodon
git fetch upstream --tags
git checkout -b <UPGRADE_BRANCH> v<TO_VERSION>
```

Then:

- [ ] Confirm `lib/mastodon/version.rb` reports `TO_VERSION`.
- [ ] Confirm `git log --oneline -1` shows the upstream release commit.
- [ ] Confirm the working tree is clean except for env/config files excluded
      by `.gitignore`.
- [ ] Delete or archive `CONFLICT_CHECKLIST.md` if it still exists from the
      previous merge-based workflow; it is no longer used.

## Phase C — Gem changes & temporary wiring

1. In the gem, branch from `main`:

   ```bash
   cd newsmast_mastodon
   git checkout main && git pull --ff-only
   git checkout -b mastodon-<TO_VERSION>
   ```

2. Update the compatibility contract:

   - [ ] `lib/newsmast_mastodon/version.rb` → `VERSION = "<TO_VERSION>.0"`
   - [ ] `newsmast_mastodon.gemspec` → `mastodon_version_requirement = "<TO_VERSION>"`
   - [ ] `README.md` compatibility section
   - [ ] `CHANGELOG.md` (`Unreleased` → new section)

   Run the sync check to confirm all four agree:

   ```bash
   bundle exec rspec spec/compatibility/version_sync_spec.rb
   ```

3. Update patched concerns/services for any upstream API/signature changes.
4. Move fork-specific Chewy index scope changes (e.g. `without_banned`) into the
   engine's `app/chewy/newsmast_mastodon/` definitions so the host can keep
   Mastodon's upstream Chewy files verbatim. The engine replaces the host
   constants at boot time via `config/initializers/prepend_concerns.rb`.
5. Guard every gem migration (see Phase D). Run:

   ```bash
   bundle exec rspec spec/compatibility/migration_guard_spec.rb
   ```

6. **Temporarily** point the host Gemfile at the dev branch for integration,
   using the same repository defined in `GEM_REPO` from the Release intake block:

   ```ruby
   gem "newsmast_mastodon",
      git: "<GEM_REPO>",
       branch: "mastodon-<TO_VERSION>"
   ```

   ```bash
   cd ../patchwork-mastodon && bundle install
   ```

> Because the host repo is an unmodified upstream snapshot, **every**
> Patchwork/Newsmast customization must be present in the gem. If a feature
> currently relies on a file that was previously committed to the host fork,
> that file must be moved into the gem (concern, override, rake task, or
> initializer) before release.

## Phase D — Database and boot (host)

1. Apply migrations against a **staging clone first**:

   ```bash
   bin/rails db:migrate
   ```

   > No migration files may be added to the host repo. All schema changes
   > ship from the gem engine and must be idempotent.

2. Confirm no collision with columns that upstream may now ship natively:
   - `status_edits.quote_id`
   - `statuses.fetched_replies_at`
   - `statuses.local_only`
   - `announcements.notification_sent_at`

   All gem migrations must be idempotent (`if_not_exists` / `column_exists?` /
   `table_exists?`); the `migration_guard_spec` enforces this in CI.

3. Install gem-shipped Chewy indexes and frontend overrides:

   ```bash
   bin/rails newsmast_mastodon:install
   yarn build:development   # or build:production
   ```

   After running install, `git status` in the host repo should show only the
   files that the rake task is designed to overwrite plus any env/config files
   excluded by `.gitignore`.

4. Verify boot and version:

   ```bash
   bin/rails runner 'puts Mastodon::Version.to_s'
   ```

   Watch the log for the gem's runtime compatibility assertion. A mismatch
   between `Mastodon::Version` and the gem's `mastodon_version_requirement`
   warns in development/test and **aborts** in production.

## Phase E — Verification gates

1. Gem suite (standalone):

   ```bash
   cd newsmast_mastodon && bundle exec rspec
   ```

2. Gem suite against the upgraded core (host mode):

   ```bash
   MASTODON_ROOT=/absolute/path/to/patchwork-mastodon bundle exec rspec
   ```

3. **Frontend-override drift check** — the gem vendors copies of upstream
   files. The drift manifest in [`config/override_baselines.yml`](../../../config/override_baselines.yml)
   must include every upstream file copied by
   [`lib/tasks/newsmast_mastodon/install.rake`](../../../lib/tasks/newsmast_mastodon/install.rake).
   Because the host branch is a clean upstream snapshot, drift is detected by
   comparing the gem's vendored copy against the upstream file in the host. If
   upstream changed any tracked file in this range, re-base the vendored copy,
   then re-record the baseline.

   Tracked upstream override paths for this cycle:
   - `app/javascript/mastodon/actions/compose.js`
   - `app/javascript/mastodon/reducers/compose.js`
   - `app/javascript/mastodon/features/compose/components/compose_form.jsx`
   - `app/javascript/mastodon/features/compose/containers/compose_form_container.js`
   - `app/javascript/mastodon/features/status/components/detailed_status.tsx`
   - `app/views/admin/shared/_status.html.haml`

   ```bash
   bin/check-override-drift /absolute/path/to/patchwork-mastodon
   ```

4. **Override-manifest completeness check** — confirm every upstream file
   copied by `install.rake` has a matching `upstream: true` entry in
   `config/override_baselines.yml`. New overrides added to the rake task must
   also be added to the manifest before the drift check can protect them.

5. **Chewy compatibility gate** — compare upstream Chewy index DSL/signature
   changes in this release range against the engine classes under
   `app/chewy/newsmast_mastodon` and confirm custom scopes (e.g.
   `without_banned`) are still valid and loaded by
   `config/initializers/prepend_concerns.rb`.

6. Concern/prepend ordering boot check — confirm no `already defined` /
   `NoMethodError` from `config/initializers/prepend_concerns.rb`.

7. Host core suite:

   ```bash
   cd patchwork-mastodon && bundle exec rspec
   ```

8. Manual smoke checklist:
   - [ ] Login / session
   - [ ] OAuth token issuance (Doorkeeper password grant)
   - [ ] Password change / reset flow
   - [ ] Post create / edit / draft flow
   - [ ] Local-only post behavior
   - [ ] Custom feeds / timelines
   - [ ] Banned-keyword filtering
   - [ ] Admin authentication / dashboard
   - [ ] Deep links (`apple-app-site-association`, `assetlinks.json`)

9. Classify any failure as:
   - [ ] Environment/infrastructure (missing services, credentials, tooling)
   - [ ] Regression in the upstream snapshot for this version
   - [ ] Regression in patched gem behavior
   - [ ] Vendored-override drift

## Phase RELEASE — Publish the gem

Only after all Phase E gates pass on the gem dev branch:

1. Open a PR `mastodon-<TO_VERSION>` → `main`; require green CI.
2. Merge, then release per [`release.md`](./release.md):

   ```bash
   git checkout main && git pull --ff-only
   git tag -s v<GEM_VERSION> -m "Release v<GEM_VERSION>"
   git push origin v<GEM_VERSION>
   ```

3. Confirm the version is live on RubyGems.

## Phase F — Pin & ship to staging (host)

1. Replace the temporary branch source with the released, exact pin:

   ```ruby
   gem "newsmast_mastodon", "<GEM_VERSION>"
   ```

   ```bash
   bundle install
   ```

2. Commit, push `<UPGRADE_BRANCH>`, deploy `csidnet-<TO_VERSION>-staging`.
3. Re-run the smoke checklist in staging.
4. Record the go/no-go decision in your report.

## Phase G — Production

1. Deploy `csidnet-<TO_VERSION>-production` once staging passes.
2. Record deployment time and any issues in the report.

---

## High-risk watchlist (every release)

- [ ] Auth stack: Devise / Doorkeeper / session strategy / token flow changes
      (the gem registers a Doorkeeper password grant in `engine.rb`).
- [ ] Controller/service signature changes where gem concerns prepend/override.
- [ ] Model API changes affecting patched `Status`, `Quote`, `MediaAttachment`,
      `User`, `Account`, `Tag`, `Notification` concerns.
- [ ] Serializer/autoload constant changes that break gem namespace loading.
- [ ] Migration collisions where gem columns may already exist in core schema.
- [ ] Upstream changes to any **vendored** frontend/view file (drift check).
- [ ] Override-manifest mismatch: any upstream-overridden file copied by
      `install.rake` but missing from `config/override_baselines.yml` reduces
      drift-check coverage.
- [ ] Chewy index DSL drift in upstream core versus engine overrides under
      `app/chewy/newsmast_mastodon`.
- [ ] Upstream security hardening that changes request validation, federation,
      or URL checks.

## Rollback

Because the host branch is a clean upstream snapshot, rollback does not require
reverting merged code.

- [ ] Abandon `<UPGRADE_BRANCH>` if the release is blocked.
- [ ] Restore the database from the pre-migration backup snapshot.
- [ ] Re-pin the host Gemfile to the last known-good gem version and `bundle install`.
- [ ] Re-point deploy configuration to the last known-good branch/tag.
- [ ] Record the rollback reason and remediation tasks in the report.
