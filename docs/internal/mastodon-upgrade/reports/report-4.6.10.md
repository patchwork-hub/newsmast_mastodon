# Mastodon Upgrade Report: v4.6.5 → v4.6.10

**Execution Date:** 2026-11-16  
**Status:** PHASE C COMPLETE. Host snapshot branch created locally, Phase B.5
impact analysis done, gem changes made, and gem standalone suite green. Phase D
(migrate/boot against a staging clone) and later phases are not started.

## Release Intake

```text
FROM_VERSION:    4.6.5
TO_VERSION:      4.6.10
TARGET_TAG:      https://github.com/mastodon/mastodon/releases/tag/v4.6.10
TARGET_COMMIT:   107f4e745a
BASE_BRANCH:     patchwork-mastodon-4.6.5
UPGRADE_BRANCH:  patchwork-mastodon-4.6.10
CORE_REMOTE:     https://github.com/mastodon/mastodon.git
GEM_REPO:        https://github.com/patchwork-hub/newsmast_mastodon
GEM_BASE_BRANCH: mastodon-4.6.5.3   # see Pre-flight note: 4.6.5.2/.3 never released
GEM_DEV_BRANCH:  mastodon-4.6.10
GEM_VERSION:     4.6.10.0
HOST_MODIFICATION_POLICY: upstream snapshot + generated gem artifacts only;
                          all customization ships via newsmast_mastodon
```

> **Note:** upstream already has `v4.6.11`. This cycle targets 4.6.10 as
> planned. Read the 4.6.11 notes before release and decide whether to retarget.

## What was collected for this release

- **Release-notes delta:** 73 upstream commits across 4.6.6, 4.6.7, 4.6.8,
  4.6.9 and 4.6.10 (all read).
- **Security entries:**
  - 4.6.10: GHSA-288h-6j8h-6x5j: insufficient ActivityPub identifier verification
  - 4.6.10: dependency advisories (Ruby, Node, `excon`, `css_parser`, `pghero`, `sanitize`)
  - 4.6.9: dependency updates; `POST /api/v1/accounts` reachable with `SSO_ACCOUNT_SIGN_UP` (#40681)
  - 4.6.8: HEIF support temporarily disabled (`config/initializers/vips.rb`)
  - 4.6.7: GHSA-vx32-x96w-qq65: 2FA password bypass for LDAP/PAM/SSO accounts
  - 4.6.7: GHSA-vgm8-frgh-rh2v: JSON-LD DoS
  - 4.6.7: GHSA-62j4-hvj7-px3f: disabled staff still had admin API access
- **Core migrations:** none (`db/migrate`, `db/post_migrate` unchanged).
- **Ruby / Node:** Ruby 4.0.5 → 4.0.9, which is inside the gemspec range
  `>= 3.3.0, < 4.1.0`. Gem CI host-mode jobs bumped to 4.0.9. Node: NodeJS
  security update only, with no `.nvmrc` major change.
- **Major dependency jumps:** Rails 8.1.3 → 8.1.3.1, **Doorkeeper 5.9.2 → 5.9.9**
  (auth stack; gem's password-grant ivar hooks verified against 5.9.9),
  pghero 3.8 → 4.1, rack-proxy 0.8 → 2.0, vite_ruby 3.10 → 3.11. Gem runtime
  deps (`jwt 2.10.3`, `faraday 2.14.3`, `parslet 2.0.0`) still satisfy the gemspec.
- **Vendored files:** no upstream change to any file the gem vendors
  (frontend, view, Chewy). `chewy` gem version unchanged.

**Estimated risk:** Low–medium. The security-relevant code paths are inherited
from upstream. The one real gap (the stale `PostStatusService#call` copy) is
fixed in the gem.

## Execution Checklist

### Pre-flight

- [x] Clean working tree in both repos.
- [x] Host `upstream` remote = `CORE_REMOTE`; `v4.6.10` fetched.
- [ ] `GEM_BASE_BRANCH` contains every released gem patch for 4.6.5. **Finding:**
      `4.6.5.1` is the last documented release. `VERSION` was set to `4.6.5.3`
      by commit `b832e84` (reverting a 4.7.5 attempt) with no CHANGELOG entry
      or tag. There are no `v4.6.5.x` git tags, and RubyGems only has
      `newsmast_mastodon 0.1.0`. The post-4.6.5.1 work is recorded under
      `4.6.10.0` in `CHANGELOG.md`.
- [ ] Staging DB backup: pending (Phase D).
- [ ] Gem CI green on base branch: not verified (base branch `version_sync_spec`
      would have failed: VERSION 4.6.5.3 with latest CHANGELOG entry 4.6.5.1).
- [ ] DevOps confirmation for staging config: pending.

### Phase A-B: Create host snapshot branch

- [x] `git checkout -b patchwork-mastodon-4.6.10 v4.6.10` (local only, not pushed)
- [x] `lib/mastodon/version.rb` reports 4.6.10
- [x] HEAD = `107f4e745a Bump version to v4.6.10`
- [x] Clean working tree

### Phase B.5: Hook-point impact analysis

| Upstream file | Gem hook | Changed methods overlap gem? | Verdict |
| --- | --- | --- | --- |
| `app/services/post_status_service.rb` | `DraftStatusService` (full copy of `#call`) | Yes. `#call` reorders `preprocess_attributes!`, adds `IdempotencyError`; gem copy also predated the `with_idempotency` redis lock | **Fixed**. Refactored to `super`-calling hooks |
| `app/services/post_status_service.rb` | `PostStatusServiceExtension` (`#postprocess_status!`, `#status_attributes`) | No. Those methods are unchanged | Compatible |
| `app/controllers/api/v1/accounts_controller.rb` | `AccountsCreation#create` (full copy) | No. Fix is in `check_enabled_registrations` before_action, which still runs | Compatible |
| `app/controllers/auth/sessions_controller.rb` | `CustomSessionBehavior#create` | No. Fix is in `find_user_from_params` | Compatible |
| `app/controllers/concerns/auth/two_factor_authentication_concern.rb` | (via `Auth::SessionsController`) | No. Gem doesn't override `authenticate_with_two_factor` | Compatible |
| `app/models/user.rb` | `UserConcern`, `OverridePrepareNewUser`, `OverrideChangedPassword` | No. `external_or_valid_password?` removed upstream, but the gem doesn't call it | Compatible |
| `config/initializers/doorkeeper.rb` + Doorkeeper 5.9.9 | `engine.rb` password grant | No. Grant requires `valid_password?` for local users and rejects OTP users; `@grant_flows`/`@resource_owner_from_credentials` ivars unchanged in 5.9.9 | Compatible (smoke test) |
| `app/controllers/admin/base_controller.rb`, `app/policies/application_policy.rb` | `class_eval before_action :authenticate_user!` on Admin Dashboard/Reports | Yes, by ordering. Upstream's new `require_moderator_or_admin_permissions` runs first and returns 403 to anonymous users before the gem's sign-in redirect | **Fixed**. Now `prepend_before_action` |
| `app/lib/account_statuses_filter.rb` | `ExtendedAccountStatusesFilter#results` (full copy) | No. Fix is in `filtered_scope` (reached via `initial_scope`) | Compatible |
| `app/models/tag_feed.rb` | `PublicFeedConcern#get` (prepended on `PublicFeed`) | No. `TagFeed#get` is defined on the subclass and wins | Compatible |
| `app/services/batched_remove_status_service.rb` | `BatchedRemoveStatusServiceExtension#unpush_from_home_timelines` | No | Compatible |
| `app/models/concerns/account/associations.rb` | `AccountConcern` | No (new `has_many :generated_annual_reports`) | Compatible |
| `app/lib/activity_tracker.rb` | used by `OverridePrepareNewUser` | No (range fix in `sum`) | Compatible |
| ActivityPub fetch/verify services, `json_ld_helper.rb`, `webfinger.rb` (GHSA-288h, GHSA-vgm8) | none (`ActivityCreateRelayExtension#create_status` calls `super`) | No | Compatible |
| `app/chewy/*`, `config/initializers/devise.rb` | Chewy copies / none | Not changed upstream | Compatible |

Other findings:

- The override manifest did not track the 3 Chewy indexes copied by
  `install.rake`, so drift checks were skipped for them. **Fixed:** added with
  4.6.10 baselines, after confirming the gem copies equal upstream 4.6.10 plus
  `without_banned` and the namespace wrapper.
- Upstream has the same singular-association typo in its own
  `PostStatusService#schedule_status!` rescue (`@account.scheduled_status`).
  This is upstream's bug, so it is noted here and not patched.

### Phase C: Gem changes & temporary wiring

- [x] Branch `mastodon-4.6.10` (already existed; based on `mastodon-4.6.5.3` history).
- [x] `VERSION = "4.6.10.0"`; gemspec `mastodon_version_requirement = "4.6.10"`;
      README mapping; CHANGELOG `[4.6.10.0]`. `version_sync_spec` green.
- [x] Needs-fix rows fixed, with specs:
  - `DraftStatusService` → hooks; `spec/services/newsmast_mastodon/draft_status_service_spec.rb`
    (7 standalone + 2 host-mode idempotency examples). Also fixed the
    `patchwork_drafted_status` typo on the Antispam path and drafted
    idempotency lookup.
  - Admin auth ordering → `prepend_before_action` in `config/initializers/prepend_concerns.rb`.
- [x] Chewy: upstream unchanged; no re-base needed.
- [x] `migration_guard_spec` green (no new gem migrations).
- [ ] Host Gemfile → git `branch: mastodon-4.6.10` (needs the gem branch pushed first).
- [x] CI `host_mastodon_ref` default → `patchwork-mastodon-4.6.10`; host-mode Ruby → 4.0.9.
      (Host-mode CI fails until `patchwork-mastodon-4.6.10` is pushed.)
- [x] Added `spec/compatibility/override_manifest_spec.rb`, which automates Phase E.4.

### Phase D: Database and boot (host, local dev, 2026-11-16)

Host Gemfile points at `git: GEM_REPO, branch: mastodon-4.6.10`, with a
Bundler local override (`bundle config --local local.newsmast_mastodon <gem checkout>`,
stored in the git-ignored `.bundle/config`) so the uncommitted gem working
tree is tested. `Gemfile.lock` records revision `29df76a`. Re-run
`bundle install` after the gem branch is pushed.

- **Local DB finding:** `patchwork-demo` had 27 `NO FILE` migrations, all
  upstream **4.7.0** migrations (left over from the reverted 4.7.5 attempt),
  so it can't represent a 4.6.5 → 4.6.10 upgrade, and migrating it would dump
  4.7 tables into `db/schema.rb`. It was backed up (`pg_dump -Fc`) and **not
  modified**. Phase D ran on a new scratch DB `patchwork_upgrade_4610` loaded
  from `patchwork-mastodon-4.6.5:db/schema.rb` (606 migrations, head
  `2026_06_22_000002`).
- [x] `bin/rails newsmast_mastodon:install` copied 3 Chewy + 7 JS + 1 view
      files and wrote the marker. **Gem bug found and fixed:** the install
      guard blocked `bin/rails newsmast_mastodon:install` (ARGV consumed by
      Rails before boot). Install must also precede migrate; runbook updated.
- [x] `bin/rails db:migrate` ran with no pending migrations (none upstream, none
      new in the gem). Regenerated `db/schema.rb` is **identical** to
      `patchwork-mastodon-4.6.5:db/schema.rb`. Model changes are schema
      annotations only (`account.rb`, `media_attachment.rb`, `status.rb`, `user.rb`).
- [x] Collision columns present once: `status_edits.quote_id`,
      `statuses.fetched_replies_at`, `statuses.local_only`,
      `announcements.notification_sent_at`.
- [x] `yarn build:development` built OK (17.6s). Local Node is 24.11.1 vs `.nvmrc` 24.17.
- [x] Boot: `Mastodon::Version` 4.6.10, gem 4.6.10.0, requirement 4.6.10, so
      no compatibility warning. Prepend chain is
      `DraftStatusService → PostStatusServiceExtension → PostStatusService`.
      Admin Dashboard's first before-callback is `authenticate_user!`.
      Doorkeeper grant flows include `password`. Installed Chewy indexes
      contain `without_banned`.
- [x] Host `git status` shows only policy-listed generated artifacts:
      Gemfile, Gemfile.lock, db/schema.rb, model annotations,
      `.newsmast_mastodon_installed`, Chewy/JS/view overrides.

### Phase E: Verification gates

- [x] E.1 Gem standalone: **453 examples, 0 failures, 102 pending** (host-only).
- [ ] E.2 Gem host mode (`MASTODON_ROOT=...`)
- [x] E.3 Override drift: `bin/check-override-drift` → all 9 upstream overrides match.
- [x] E.4 Manifest completeness: `override_manifest_spec` green (13 examples).
- [ ] E.5 Chewy gate (`tootctl search deploy`)
- [ ] E.6 Prepend ordering boot check
- [ ] E.7 Host core suite
- [ ] E.8 Manual smoke. Add per-security checks: LDAP/PAM 2FA login
      (GHSA-vx32); disabled moderator denied on admin web + API (GHSA-62j4);
      `POST /api/v1/accounts` 403 with `SSO_ACCOUNT_SIGN_UP` (#40681); double
      submit with same `Idempotency-Key` for posts **and drafts**; anonymous
      `/admin/dashboard` redirects to sign-in.

### Phase RELEASE / F / G

- [ ] Not started. **Blocker to resolve:** RubyGems only has `0.1.0`. Confirm
      how `X.Y.Z.N` versions are distributed (private gem server / git tag)
      before Phase RELEASE step 4 and Phase F pinning.

## Rollback

Not applicable yet. Nothing has been pushed or deployed.
