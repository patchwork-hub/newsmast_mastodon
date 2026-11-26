# Mastodon 4.7.6 Upgrade Report

```
FROM_VERSION:    4.6.10
TO_VERSION:      4.7.6
TARGET_TAG:      https://github.com/mastodon/mastodon/releases/tag/v4.7.6
BASE_BRANCH:     patchwork-mastodon-4.6.10
UPGRADE_BRANCH:  patchwork-mastodon-4.7.6
CORE_REMOTE:     https://github.com/mastodon/mastodon.git
GEM_REPO:        https://github.com/patchwork-hub/newsmast_mastodon
GEM_BASE_BRANCH: mastodon-4.6.10
GEM_DEV_BRANCH:  mastodon-4.7.6
GEM_VERSION:     4.7.6.0
HOST_MODIFICATION_POLICY: upstream snapshot + generated gem artifacts only;
                          all customization ships via newsmast_mastodon
```

## Phase A-B

- [ ] Clean preflight for both repositories.
- [x] Target `v4.7.6` is available locally.
- [x] Host upgrade branch created directly from upstream `v4.7.6`.
- [ ] Host version/commit verification.

## Collection summary

- Target/runtime: Ruby `4.0.10`, Node `24.19`.
- Relevant upstream changed-file count: 420 Ruby/config/frontend/migration
  files in the `4.6.10 -> 4.7.6` range.
- Core migration candidates: 19 migration/post-migration files were added or
  changed; collision review remains required.
- Known full-method copies are unchanged structurally, but upstream overlap
  must be verified against each method.

## Phase B.5 hook-point impact

| Upstream file | Gem hook | Changed methods overlap gem? | Verdict |
| --- | --- | --- | --- |
| `app/controllers/api/v1/accounts_controller.rb` | `AccountsCreation#create` | No overlap: upstream changes private account lookup methods | Compatible |
| `app/services/post_status_service.rb` | `PostStatusServiceExtension#postprocess_status!`, `#status_attributes` | Partial: upstream rescue changed; gem overrides remain separate | Needs verification |
| `app/lib/account_statuses_filter.rb` | `ExtendedAccountStatusesFilter#results` | No upstream file change in the range | Compatible |
| `app/models/user.rb` | `OverridePrepareNewUser#prepare_new_user!` | No direct method overlap; upstream added sign-in-token and invite hooks | Needs verification |
| `app/controllers/auth/sessions_controller.rb` | `CustomSessionBehavior#create` | Both define `create`; gem calls `super` | Needs verification |
| `app/controllers/concerns/auth/two_factor_authentication_concern.rb` | upstream auth callbacks plus gem token behavior | Sign-in flow changed upstream | Needs verification |
| `app/controllers/concerns/auth/sign_in_token_authentication_concern.rb` | gem custom session/auth behavior | New upstream concern in 4.7.6 | Needs verification |
| `app/chewy/*.rb` | install-time Chewy copies | No changed upstream index file names detected | Compatible |
| compose action/container/status detail | install-time frontend copies | Upstream files changed; gem copies re-based onto 4.7.6 | Fixed |
| federated dropdown | gem-only install-time frontend copy | Mastodon 4.7.6 removed `react-overlays/Overlay` dependency | Fixed |
| `app/views/admin/shared/_status.html.haml` | install-time view copy | No diff detected in range | Compatible |

## Gem host surfaces

The upgrade must account for more than gem dependencies:

- Boot-time `include`/`prepend`/`class_eval` wiring for models, services,
  serializers, filters, controllers, auth, and admin callbacks.
- Rails engine compatibility assertion, route mounting, autoload paths,
  migrations, allowed-host setup, and Doorkeeper password grant.
- Install-time copies of Chewy indexes and frontend/view overrides.
- Migration collision guards and host installation marker.

## Vendored override re-base

- Re-based the compose action, compose container, and detailed status copy onto
  upstream `v4.7.6`, while preserving the Newsmast local-only and federated
  dropdown behavior.
- Unchanged upstream vendored files remain candidates for baseline refresh;
  run `bin/check-override-drift ... --update` against the clean 4.7.6 host.

## Verification

- [ ] Standalone gem suite.
- [ ] Host-mode gem suite.
- [ ] Override drift and manifest checks.
- [ ] Chewy compatibility.
- [ ] Concern/prepend boot check.
- [ ] Core host suite.
- [ ] Manual smoke/security checklist.
