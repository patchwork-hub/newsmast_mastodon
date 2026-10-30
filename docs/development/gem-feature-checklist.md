# Gem Feature Split Checklist

Inventory date: 2026-10-07.

This inventory tracks features present in this gem and the work needed to split
them into two gems. It does not assign features to either gem or perform the
extraction. The [existing split proposal](../../newsmast_gems_split.md) is background,
not an ownership decision. Upstream Mastodon features are included only where this
gem extends them; generated coverage assets are not product features.

## Progress Legend

Every item starts with **Target gem: Undecided**. Replace that value when its
destination is agreed. Track the three stages independently:

- **Assigned:** destination and dependency ownership recorded.
- **Migrated:** implementation, routes, assets, configuration, migrations and jobs
  moved as applicable, with host wiring updated.
- **Verified:** relevant behavior, installation and dependency checks passed;
  record the commands/results or review evidence alongside the item.

Implementation state describes source code, not migration progress or a runtime
guarantee. "Implemented" means behavior exists; "configuration-dependent" requires
external settings/services; "disabled" means identified registration is inactive;
"needs confirmation" means the complete flow has not been established.
Linked specs are verification starting points, not evidence that tests passed.
Application tests were not run for this documentation inventory.

## Authentication and Accounts

### AUTH-01: Password Recovery, OTP and Credential Changes

Request and verify email OTPs, reset passwords, change passwords and email
addresses, and send recovery mail. Confirmation also interacts with waitlist state.

Target gem: Undecided. State: implemented.

Sources: [custom_passwords_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/custom_passwords_controller.rb),
[custom_passwords_mailer.rb](../../app/mailers/custom_passwords_mailer.rb).
Dependencies: Devise, mail delivery, user fields, waitlist and account/bot updates.
Verification: [custom_passwords_spec.rb](../../spec/requests/newsmast_mastodon/api/v1/custom_passwords_spec.rb);
check expiry, invalid/reused OTPs, authorization and email-change confirmation.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### AUTH-02: Login and OAuth Authentication Extensions

OAuth password grant with LDAP/PAM/password authentication and MFA exclusion,
plus custom token/session authentication and login service behavior.

Target gem: Undecided. State: configuration-dependent.

Sources: [engine.rb](../../lib/newsmast_mastodon/engine.rb),
[custom_authentication_behavior.rb](../../app/controllers/newsmast_mastodon/concerns/custom_authentication_behavior.rb),
[custom_session_behavior.rb](../../app/controllers/newsmast_mastodon/concerns/custom_session_behavior.rb),
[login_service.rb](../../app/services/newsmast_mastodon/login_service.rb).
Dependencies: Doorkeeper, Devise and the host authentication configuration.
Verification: [login_service_spec.rb](../../spec/services/newsmast_mastodon/login_service_spec.rb);
check web and token flows separately, including disabled accounts and MFA.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### AUTH-03: Bristol Cable Membership Sign-In

Authenticate against the membership service and connect the result to the local
login/registration response.

Target gem: Undecided. State: configuration-dependent.

Sources: [bristolcable_login_service.rb](../../app/services/newsmast_mastodon/bristolcable_login_service.rb),
[custom_passwords_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/custom_passwords_controller.rb).
Dependencies: external membership service, local accounts and token generation.
Verification: [bristolcable_login_service_spec.rb](../../spec/services/newsmast_mastodon/bristolcable_login_service_spec.rb);
exercise rejection, service failure and registration-required responses.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### AUTH-04: CiviCRM Membership, Profile Fields and Roles

Membership checks for registration, membership-derived profile fields, role lookup
and asynchronous role assignment; maintenance tasks backfill fields and roles.

Target gem: Gem B (`patchwork_extensions`). State: extracted; Gem A route and
the AccountsCreation prepend disabled at cutover (2026-10-30); host-mode
request specs plus standalone-capable service/worker/concern specs pass (61
examples, 0 failures targeted host-mode; full Gem B host suite 124 examples,
6 pre-existing COMMUNITY-03 failures; standalone 124 examples, 0 failures,
73 pending; Gem A sanity specs 42 examples, 0 failures, 7 pending).

Gem A sources (disabled, marked `GEM_SPLIT[AUTH-04]`; remove after the
verification window):
[config/routes.rb](../../config/routes.rb) (`post "civicrm_role_assign"`,
commented out),
[config/initializers/prepend_concerns.rb](../../config/initializers/prepend_concerns.rb)
(`Api::V1::AccountsController.prepend(...AccountsCreation)`, commented out),
[civicrm_role_assignments_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/civicrm_role_assignments_controller.rb)
(unrouted; this endpoint was missing from the original source list and was
discovered during extraction) and
[accounts_creation.rb](../../app/controllers/newsmast_mastodon/concerns/accounts_creation.rb)
(unwired). The Gem A request specs were deleted at cutover (moved to Gem B).

Gem A sources retained (still active; remove after the verification window):
[civicrm_membership_check_service.rb](../../app/services/newsmast_mastodon/civicrm_membership_check_service.rb),
[civicrm_role_check_service.rb](../../app/services/newsmast_mastodon/civicrm_role_check_service.rb),
[civicrm_role_assignment_worker.rb](../../app/workers/newsmast_mastodon/civicrm_role_assignment_worker.rb)
stay for in-flight jobs (INFRA-05), and
[csid_membership_fields.rake](../../lib/tasks/newsmast_mastodon/csid_membership_fields.rake),
[csid_role_assignment.rake](../../lib/tasks/newsmast_mastodon/csid_role_assignment.rake)
stay runnable under the `newsmast_mastodon:` namespace during the window
(same treatment as BOOST-01's retained service).

Gem B sources (sibling repo `patchwork_extensions`):
[civicrm_membership_check_service.rb](../../../patchwork_extensions/app/services/patchwork_extensions/civicrm_membership_check_service.rb),
[civicrm_role_check_service.rb](../../../patchwork_extensions/app/services/patchwork_extensions/civicrm_role_check_service.rb),
[civicrm_role_assignment_worker.rb](../../../patchwork_extensions/app/workers/patchwork_extensions/civicrm_role_assignment_worker.rb),
[civicrm_role_assignments_controller.rb](../../../patchwork_extensions/app/controllers/patchwork_extensions/api/v1/civicrm_role_assignments_controller.rb),
[accounts_creation.rb](../../../patchwork_extensions/app/controllers/patchwork_extensions/concerns/accounts_creation.rb),
[patchwork_mastodon_helper.rb](../../../patchwork_extensions/app/helpers/patchwork_mastodon_helper.rb),
[prepend_concerns.rb](../../../patchwork_extensions/config/initializers/prepend_concerns.rb),
[routes.rb](../../../patchwork_extensions/config/routes.rb),
[config/locales/en.yml](../../../patchwork_extensions/config/locales/en.yml),
[csid_membership_fields.rake](../../../patchwork_extensions/lib/tasks/patchwork_extensions/csid_membership_fields.rake),
[csid_role_assignment.rake](../../../patchwork_extensions/lib/tasks/patchwork_extensions/csid_role_assignment.rake).

Dependencies: external CiviCRM API, the `CIVICRM_BASE_URL`,
`CIVICRM_AUTH_TOKEN`, `CSID_MEMBERSHIP_CHECK_ENABLED`,
`CSID_MEMBERSHIP_ALLOWLIST_EMAILS` and `CSID_ROLE_ASSIGNMENT_ENABLED` ENV vars,
host `User`/`UserRole`/`AppSignUpService`/`ValidationErrorFormatter`, Sidekiq,
and Gem A's `CustomPasswordsMailer` (AUTH-01, undecided — the carried
`generate_opt_token` call is guarded by `defined?(CustomPasswordsMailer)`).
The patchwork tables stay Gem A-owned per the split decision: Gem B's
`create_community_admin` reaches `NewsmastMastodon::CommunityAdmin` through
the guarded `patchwork_community_admin_exist?` check in the unified
`PatchworkMastodonHelper` (which replaces Gem A's NonChannelHelper,
PatchworkHelper and MoMeHelper for this concern); no Gem B migrations are
introduced. The Gem B `create` override is monolithic like Gem A's, so the
AUTH-01 OTP generation and AUTH-05 account params/signup-reason defaults ride
along unchanged until those features are assigned. Gem B's rake tasks are
re-namespaced to `patchwork_extensions:remove_csid_badge_fields`,
`patchwork_extensions:backfill_csid_badge_fields` and
`patchwork_extensions:backfill_csid_roles` (behavior unchanged). Gem B's
dummy app now requires `active_model/railtie` so the extracted ENV-flag casts
load standalone. The `api.account.errors.membership_not_eligible` locale key
was duplicated into Gem B's en.yml (English only; Gem A still ships the other
locales until the window closes).
Verification: [accounts_registration_membership_spec.rb](../../../patchwork_extensions/spec/requests/patchwork_extensions/api/v1/accounts_registration_membership_spec.rb)
(host-mode: membership-gate 422, signup service not called),
[civicrm_role_assignments_spec.rb](../../../patchwork_extensions/spec/requests/patchwork_extensions/api/v1/civicrm_role_assignments_spec.rb)
(host-mode: enqueue, 401 without token, 403 when disabled, 403 without write
scope),
[civicrm_membership_check_service_spec.rb](../../../patchwork_extensions/spec/services/patchwork_extensions/civicrm_membership_check_service_spec.rb)
(standalone-capable: disabled/forced modes, allowlist, user-group extraction),
[civicrm_role_check_service_spec.rb](../../../patchwork_extensions/spec/services/patchwork_extensions/civicrm_role_check_service_spec.rb)
(standalone-capable: group priority, transient failures),
[civicrm_role_assignment_worker_spec.rb](../../../patchwork_extensions/spec/workers/patchwork_extensions/civicrm_role_assignment_worker_spec.rb)
(standalone-capable: role mapping, no-overwrite, transient retry) and
[accounts_creation_spec.rb](../../../patchwork_extensions/spec/controllers/patchwork_extensions/concerns/accounts_creation_spec.rb)
(standalone-capable: enqueue gating, signup-reason default). Evidence recorded
in
[gem-split-implementation-log.md](../../../patchwork_extensions/docs/development/gem-split-implementation-log.md).
Cutover: DONE (2026-10-30) — Gem A route and AccountsCreation prepend
commented out.

- [x] Assigned
- [x] Migrated
- [x] Verified

### AUTH-05: Signup Defaults, Profile Updates and Auto-Follow

Custom account creation/update parameters, new-user defaults, optional signup
email-domain restrictions and following configured accounts after signup.
Search/bridge defaults are tracked under MOD-03.

Target gem: Undecided. State: implemented; optional policies are configuration-dependent.

Sources: [accounts_creation.rb](../../app/controllers/newsmast_mastodon/concerns/accounts_creation.rb),
[accounts_update.rb](../../app/controllers/newsmast_mastodon/concerns/accounts_update.rb),
[user_concern.rb](../../app/models/newsmast_mastodon/concerns/user_concern.rb),
[auto_follow_default_accounts_service.rb](../../app/services/newsmast_mastodon/auto_follow_default_accounts_service.rb).
Dependencies: signup service override, account serializers and shared settings.
Verification: [accounts_creation_spec.rb](../../spec/controllers/newsmast_mastodon/concerns/accounts_creation_spec.rb),
[auto_follow_default_accounts_service_spec.rb](../../spec/services/newsmast_mastodon/auto_follow_default_accounts_service_spec.rb).

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### AUTH-06: Account Deletion and Locale Preferences

Custom deletion endpoints and authenticated user locale updates. Preserve both
deletion entry points and their different request/response contracts.

Target gem: Gem B (`patchwork_extensions`). State: extracted; Gem A routes
disabled at cutover (2026-10-13); host-mode request specs pass (11 examples,
0 failures; full Gem B suite 58 examples, 0 failures in host mode; standalone
58 examples, 0 failures, 52 pending).

Gem A sources (disabled, marked `GEM_SPLIT[AUTH-06]`; remove after the
verification window):
[accounts_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/accounts_controller.rb),
[account_deletion_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/patchwork/account_deletion_controller.rb),
[user_locales_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/user_locales_controller.rb),
[config/routes.rb](../../config/routes.rb) (`post "/delete_account"`,
`resources :account_deletion` and `resources :user_locales` blocks, commented
out). The Gem A request specs were deleted at cutover.

Gem B sources (sibling repo `patchwork_extensions`):
[accounts_controller.rb](../../../patchwork_extensions/app/controllers/patchwork_extensions/api/v1/accounts_controller.rb),
[account_deletion_controller.rb](../../../patchwork_extensions/app/controllers/patchwork_extensions/api/v1/patchwork/account_deletion_controller.rb),
[user_locales_controller.rb](../../../patchwork_extensions/app/controllers/patchwork_extensions/api/v1/user_locales_controller.rb),
[api_response_helper.rb](../../../patchwork_extensions/app/controllers/patchwork_extensions/concerns/api_response_helper.rb),
[api_custom_response_helper.rb](../../../patchwork_extensions/app/controllers/patchwork_extensions/concerns/api_custom_response_helper.rb),
[config/locales/en.yml](../../../patchwork_extensions/config/locales/en.yml),
[routes.rb](../../../patchwork_extensions/config/routes.rb).

Dependencies: host `DeleteAccountService`, `AccountDeletionWorker`,
`Account#suspend!`, OAuth permissions and `I18n.available_locales`; no
gem-owned tables, workers, Redis keys or settings. The shared API response
helper concerns and their `api.*` message keys were duplicated into Gem B
(controllers and responses are identical; values match Gem A's locales).
Flagged for follow-up security review: `DELETE
/api/v1/patchwork/account_deletion/:id` deletes any account by id for any
authenticated user — the Gem A contract is preserved unchanged. Before-action
order differs per endpoint and is preserved: unauthenticated requests get 422
on `/delete_account` and `/user_locales` (require_user! first) and 401 on
`/patchwork/account_deletion` (doorkeeper first).
Verification: [account_deletion_spec.rb](../../../patchwork_extensions/spec/requests/patchwork_extensions/api/v1/account_deletion_spec.rb)
(host-mode: password-confirmed deletion, wrong password, unknown account 404,
no-identity-isolation contract, auth per endpoint) and
[user_locales_spec.rb](../../../patchwork_extensions/spec/requests/patchwork_extensions/api/v1/user_locales_spec.rb)
(host-mode: valid/invalid/missing `lang`, persistence, auth). Evidence recorded
in
[gem-split-implementation-log.md](../../../patchwork_extensions/docs/development/gem-split-implementation-log.md).
Cutover: DONE (2026-10-13) — Gem A routes blocks commented out.

- [x] Assigned
- [x] Migrated
- [x] Verified

## Posts and Media

### POST-01: Draft Posts and Publication

Create, list by date, retrieve, update, delete and publish drafts, with media and
post options. Publishing passes scheduling options to the host post service;
draft storage alone is not a standalone scheduling engine.

Target gem: Undecided. State: implemented.

Sources: [drafted_statuses_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/drafted_statuses_controller.rb),
[drafted_status.rb](../../app/models/newsmast_mastodon/drafted_status.rb),
[draft_status_service.rb](../../app/services/newsmast_mastodon/concerns/draft_status_service.rb).
Dependencies: draft/media migrations, serializers, account ownership, limits and PostStatusService.
Verification: [drafted_statuses_spec.rb](../../spec/requests/drafted_statuses_spec.rb),
[drafted_status_spec.rb](../../spec/models/newsmast_mastodon/drafted_status_spec.rb).

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### POST-02: Scheduled-Post Editing

Extend the host scheduled-status update flow and accepted post options.

Target gem: Undecided. State: implemented; host scheduling required.

Source: [scheduled_statuses_controller.rb](../../app/lib/newsmast_mastodon/overrides/scheduled_statuses_controller.rb).
Dependencies: host ScheduledStatus, PostStatusService and shared draft/post options.
Verification: direct behavior spec not located in the inspected slice; test edits,
ownership, media/polls, invalid times and eventual publication in the host harness.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### POST-03: Local-Only Post Controls

Local-only status attribute, post/reply/reblog handling, settings endpoint and API
serialization. The posting hook skips ActivityPub distribution for local-only
statuses. The compose controls are tracked under UI-02.

Target gem: Undecided. State: implemented controls; end-to-end federation behavior needs confirmation.

Sources: [post_status_service_extension.rb](../../app/services/newsmast_mastodon/overrides/post_status_service_extension.rb),
[status_concern.rb](../../app/models/newsmast_mastodon/concerns/status_concern.rb),
[local_only_posts_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/local_only_posts_controller.rb),
[status_serializer_extension.rb](../../app/serializers/local_only_posts/status_serializer_extension.rb).
Dependencies: status column, feed filtering, notification behavior and host federation paths.
Verification: [local_only_posts_spec.rb](../../spec/requests/local_only_posts_spec.rb),
[post_status_service_extension_spec.rb](../../spec/services/newsmast_mastodon/post_status_service_extension_spec.rb);
also prove outbound delivery and remote access restrictions, not just flag storage.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### POST-04: Extended Post Length

Custom status-length validation and instance API advertisement of posting limits.

Target gem: Undecided. State: implemented.

Sources: [status_length_validator_patch.rb](../../app/validators/long_post/status_length_validator_patch.rb),
[instance_serializer_extension.rb](../../app/serializers/long_post/instance_serializer_extension.rb).
Dependencies: host validators, instance serializers and frontend character counting.
Verification: check configured limit boundaries, URLs, spoilers and agreement between
API-advertised limits, validation and compose behavior; registration alone is insufficient.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### POST-05: Emoji Reactions and Timeline Response Data

Add/update and remove status reactions; provide reaction counts and current-user
reaction data in status/timeline, bookmark and trends responses.

Target gem: Undecided. State: implemented.

Sources: [status_reactions_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/patchwork/status_reactions_controller.rb),
[patchwork_status_reaction.rb](../../app/models/newsmast_mastodon/patchwork_status_reaction.rb),
[timeline_patchwork_post_reactions.rb](../../app/lib/newsmast_mastodon/overrides/timeline_patchwork_post_reactions.rb),
[statuses_controller_extension.rb](../../app/controllers/newsmast_mastodon/api/v1/statuses_controller_extension.rb).
Dependencies: reaction migrations, validator/serializer, host status authorization and
the controller extensions registered in INFRA-01.
Verification: dedicated reaction behavior spec not located in the inspected slice;
test uniqueness, invalid emoji, inaccessible statuses and consistent response data.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### POST-06: Post Lifecycle Extensions

Posting, editing, reblogging and single/batched removal hooks coordinate the custom
features rather than being independent copies of Mastodon's post workflows.

Target gem: Undecided. State: implemented.

Sources: [post_status_service_extension.rb](../../app/services/newsmast_mastodon/overrides/post_status_service_extension.rb),
[update_status_service_extension.rb](../../app/services/newsmast_mastodon/overrides/update_status_service_extension.rb),
[reblog_service_extension.rb](../../app/services/newsmast_mastodon/overrides/reblog_service_extension.rb),
[remove_status_service_extension.rb](../../app/services/newsmast_mastodon/overrides/remove_status_service_extension.rb),
[batched_remove_status_service_extension.rb](../../app/services/newsmast_mastodon/overrides/batched_remove_status_service_extension.rb).
Dependencies: filtering, channel distribution, local-only behavior and feed cleanup.
Verification: [post_status_service_extension_spec.rb](../../spec/services/newsmast_mastodon/post_status_service_extension_spec.rb),
[update_status_service_extension_spec.rb](../../spec/services/newsmast_mastodon/update_status_service_extension_spec.rb);
verify callbacks execute once and cleanup survives the split.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### MEDIA-01: AI Alt Text and User Preferences

External image-description API integration, upload processing, background
generation and the user opt-in settings API.

Target gem: Gem B (`patchwork_extensions`). State: extracted; Gem A routes and
the concern's alt-text callback disabled at cutover (2026-10-29); host-mode
request, service and concern specs pass (17 examples, 0 failures; Gem A sanity
specs 7 examples, 0 failures).

Gem A sources (disabled, marked `GEM_SPLIT[MEDIA-01]`; remove after the
verification window):
[config/routes.rb](../../config/routes.rb) (`resources :alttext_settings`
block, commented out) and the alt-text callback/predicate methods in
[media_attachment_concern.rb](../../app/models/newsmast_mastodon/concerns/media_attachment_concern.rb)
(commented out; the draft-post association and attached/unattached scopes stay
with POST-01). The Gem A request specs were deleted at cutover; the concern
spec moved to Gem B.

Gem A sources retained (still active; remove after the verification window):
[alt_text_ai_api_service.rb](../../app/services/newsmast_mastodon/alt_text_ai_api_service.rb),
[after_upload_image_service.rb](../../app/services/newsmast_mastodon/after_upload_image_service.rb),
[generate_alt_text_worker.rb](../../app/workers/newsmast_mastodon/generate_alt_text_worker.rb),
[alttext_get_account.rb](../../app/models/newsmast_mastodon/alttext_get_account.rb),
[alttext_create_image.rb](../../app/models/newsmast_mastodon/alttext_create_image.rb)
stay for in-flight jobs (INFRA-05) and resolve `can_generate_alt?` through Gem
B's concern while both gems are loaded (same treatment as BOOST-01's retained
service). The unrouted Gem A controller
[alttext_settings_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/patchwork/alttext_settings_controller.rb)
is also kept until the window closes.

Gem B sources (sibling repo `patchwork_extensions`):
[alttext_settings_controller.rb](../../../patchwork_extensions/app/controllers/patchwork_extensions/api/v1/patchwork/alttext_settings_controller.rb),
[media_attachment_concern.rb](../../../patchwork_extensions/app/models/patchwork_extensions/concerns/media_attachment_concern.rb),
[after_upload_image_service.rb](../../../patchwork_extensions/app/services/patchwork_extensions/after_upload_image_service.rb),
[alt_text_ai_api_service.rb](../../../patchwork_extensions/app/services/patchwork_extensions/alt_text_ai_api_service.rb),
[alttext_get_account.rb](../../../patchwork_extensions/app/models/patchwork_extensions/alttext_get_account.rb),
[alttext_create_image.rb](../../../patchwork_extensions/app/models/patchwork_extensions/alttext_create_image.rb),
[generate_alt_text_worker.rb](../../../patchwork_extensions/app/workers/patchwork_extensions/generate_alt_text_worker.rb),
[prepend_concerns.rb](../../../patchwork_extensions/config/initializers/prepend_concerns.rb),
[routes.rb](../../../patchwork_extensions/config/routes.rb).

Dependencies: host `MediaAttachment`/`User` (the `alttext_enabled` column stays
Gem A-owned schema, INFRA-03), Sidekiq, and the `ALT_TEXT_URL`,
`ALT_TEXT_SECRET`, `ALT_TEXT_ENABLED`, `ALT_TEXT_USER_TOGGLE` and
`SKIP_ALT_TEXT_USER_SETTING` ENV vars; alttext.ai is the only supported
provider. Contract quirk preserved unchanged and flagged for follow-up review:
a missing/non-boolean `enabled` param casts to nil and violates the
`users.alttext_enabled` NOT NULL constraint (raises instead of toggling).
Before-action order: doorkeeper first, so unauthenticated requests get 401
(matches AUTH-06's `/patchwork/account_deletion` contract).
Verification: [alttext_settings_spec.rb](../../../patchwork_extensions/spec/requests/patchwork_extensions/api/v1/patchwork/alttext_settings_spec.rb)
(host-mode: index value, enable/disable, missing-param quirk, auth),
[alt_text_ai_api_service_spec.rb](../../../patchwork_extensions/spec/services/patchwork_extensions/alt_text_ai_api_service_spec.rb)
(standalone-capable: request contract) and
[media_attachment_concern_spec.rb](../../../patchwork_extensions/spec/models/patchwork_extensions/concerns/media_attachment_concern_spec.rb)
(standalone-capable: content-type, existing-description, local-authorship
checks). Evidence recorded in
[gem-split-implementation-log.md](../../../patchwork_extensions/docs/development/gem-split-implementation-log.md).
Cutover: DONE (2026-10-29) — Gem A routes block and concern alt-text callback
commented out.

- [x] Assigned
- [x] Migrated
- [x] Verified

### MEDIA-02: Link Previews

Fetch link metadata for the utility preview endpoint.

Target gem: Gem B (`patchwork_extensions`). State: extracted; Gem A routes
disabled at cutover (2026-10-13); host-mode request and service specs pass
(18 examples, 0 failures; full Gem B suite 41 examples, 0 failures, run twice).

Gem A sources (disabled, marked `GEM_SPLIT[MEDIA-02]`; remove after the
verification window):
[utilities_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/utilities_controller.rb),
[fetch_link_metadata_service.rb](../../app/services/newsmast_mastodon/fetch_link_metadata_service.rb),
[config/routes.rb](../../config/routes.rb) (`resources :utilities` block,
commented out).

Gem B sources (sibling repo `patchwork_extensions`):
[utilities_controller.rb](../../../patchwork_extensions/app/controllers/patchwork_extensions/api/v1/utilities_controller.rb),
[fetch_link_metadata_service.rb](../../../patchwork_extensions/app/services/patchwork_extensions/fetch_link_metadata_service.rb),
[routes.rb](../../../patchwork_extensions/config/routes.rb).

Dependencies: host BaseService, PreviewCard caching (2-week TTL), Mastodon
Request HTTP stack, FetchOEmbedService and LinkDetailsExtractor; no gem-owned
tables, workers, Redis keys or settings. The endpoint is unauthenticated,
matching the Gem A original (flagged for follow-up security review). The
service inherits the host's top-level BaseService; Gem B's
spec/support/mastodon_stubs.rb provides a guarded fallback for standalone mode.
Verification: [utilities_spec.rb](../../../patchwork_extensions/spec/requests/patchwork_extensions/api/v1/utilities_spec.rb)
(host-mode: success, missing URL, invalid URL, fetch failure) and
[fetch_link_metadata_service_spec.rb](../../../patchwork_extensions/spec/services/patchwork_extensions/fetch_link_metadata_service_spec.rb)
(host-mode: invalid URLs, restricted destinations, remote failures, redirects,
cache freshness, oEmbed/OpenGraph extraction). Evidence recorded in
[gem-split-implementation-log.md](../../../patchwork_extensions/docs/development/gem-split-implementation-log.md).
Cutover: DONE (2026-10-13) — Gem A routes block commented out.

- [x] Assigned
- [x] Migrated
- [x] Verified

## Conversations

### CONV-01: Conversation Lookup and Read State

Find an existing conversation with a target participant and mark the current
account's unread conversations as read.

Target gem: Gem B (`patchwork_extensions`). State: extracted; Gem A routes
disabled at cutover (2026-10-09); host-mode request specs pass (17 examples,
0 failures, run twice).

Gem A sources (disabled, marked `GEM_SPLIT[CONV-01]`; remove after the
verification window):
[conversations_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/patchwork/conversations_controller.rb),
[config/routes.rb](../../config/routes.rb) (`resources :conversations` block,
commented out).

Gem B sources (sibling repo `patchwork_extensions`):
[conversations_controller.rb](../../../patchwork_extensions/app/controllers/patchwork_extensions/api/v1/patchwork/conversations_controller.rb),
[routes.rb](../../../patchwork_extensions/config/routes.rb).

Dependencies: host AccountConversation, REST::ConversationSerializer,
StatusRelationshipsPresenter and standard OAuth scopes (`read:statuses`,
`write:conversations`); no gem-owned tables, workers, Redis keys or settings.
Gem B's engine mounts at `/` via `routes.prepend` (Mastodon's
`*unmatched_route` catch-all requires prepend); endpoint URLs are unchanged.
Verification: [conversations_spec.rb](../../../patchwork_extensions/spec/requests/patchwork_extensions/api/v1/patchwork/conversations_spec.rb)
(host-mode: participant lookup, absent conversation, account isolation,
mark-all-read counts and auth). Evidence recorded in
[gem-split-implementation-log.md](../../../patchwork_extensions/docs/development/gem-split-implementation-log.md).
Cutover: DONE (2026-10-09) — Gem A routes block commented out.

- [x] Assigned
- [x] Migrated
- [x] Verified

## Feeds and Timelines

### FEED-01: Custom Account Feeds and Distribution

Account-scoped custom timeline retrieval, pagination/filter options and Redis
feed insertion/removal through feed-manager and fan-out extensions.

Target gem: Undecided. State: implemented.

Sources: [custom_feed.rb](../../app/models/newsmast_mastodon/custom_feed.rb),
[feeds_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/timelines/feeds_controller.rb),
[feed_manager_concern.rb](../../app/models/newsmast_mastodon/concerns/feed_manager_concern.rb),
[fan_out_on_write_concern.rb](../../app/models/newsmast_mastodon/concerns/fan_out_on_write_concern.rb).
Dependencies: Redis keys, CustomFeedInsertWorker, account relationships and moderation exclusions.
Verification: [custom_feed_spec.rb](../../spec/models/newsmast_mastodon/custom_feed_spec.rb),
[feeds_spec.rb](../../spec/requests/feeds_spec.rb); check insertion, pagination and removal together.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### FEED-02: For You and Mixed Channel Timeline

For You feed aggregation and maintenance of the shared channel/local-post timeline.

Target gem: Gem B (`patchwork_extensions`). State: extracted; Gem A route
disabled at cutover (2026-10-16); host-mode service spec passes. This feature is
safe to migrate because it is host-owned data access over Redis/home feed + status
callbacks, with no gem-owned tables, workers, or external configuration beyond the
existing feature flag and community/admin relationships.

Gem A sources (disabled, marked `GEM_SPLIT[FEED-02]`; remove after the
verification window):
[for_you_feed.rb](../../app/models/newsmast_mastodon/for_you_feed.rb),
[custom_timeline_service.rb](../../app/services/newsmast_mastodon/custom_timeline_service.rb),
[for_you_custom_timeline_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/timelines/for_you_custom_timeline_controller.rb),
[config/routes.rb](../../config/routes.rb) (`for_you_custom_timeline` route,
commented out).

Gem B sources (sibling repo `patchwork_extensions`):
[for_you_feed.rb](../../../patchwork_extensions/app/services/patchwork_extensions/for_you_feed.rb),
[custom_timeline_service.rb](../../../patchwork_extensions/app/services/patchwork_extensions/custom_timeline_service.rb),
[for_you_custom_timeline_controller.rb](../../../patchwork_extensions/app/controllers/patchwork_extensions/api/v1/timelines/for_you_custom_timeline_controller.rb),
[routes.rb](../../../patchwork_extensions/config/routes.rb).

Dependencies: community/admin relationships, Redis, home feed and `StatusConcern`
callbacks; feature flag gating remains host-owned. No gem-owned migrations,
workers, settings tables, or remote credentials are introduced by the split.
Verification: [custom_timeline_service_spec.rb](../../../patchwork_extensions/spec/services/patchwork_extensions/custom_timeline_service_spec.rb)
(host-mode expectation: Redis zadd/zrem writes; matching legacy key names)
with the host harness; extend to feature-disabled mode and deleted/banned content
cleanup before final cutover. Evidence recorded in
[gem-split-implementation-log.md](../../../patchwork_extensions/docs/development/gem-split-implementation-log.md).
Cutover: DONE (2026-10-16) — Gem A route commented out.

- [x] Assigned
- [x] Migrated
- [x] Verified

### FEED-03: Instances and Relay-Domain Timelines (moved)

Read relay-domain feeds and combine selected domains with home-timeline content.
Relay connection management is tracked under RELAY-01.

Target gem: Undecided. State: configuration-dependent.

Sources: [relay_feed.rb](../../app/models/newsmast_mastodon/relay_feed.rb),
[instances_timeline_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/timelines/instances_timeline_controller.rb).
Dependencies: relay ingestion, Redis keys, selected domains and host home feed.
Verification: dedicated instances-timeline behavior spec not located in the inspected
slice; test omitted/single/multiple domains, deduplication, exclusions and pagination.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

## Communities and Channels

### COMMUNITY-01: Community Structure, Visibility and Administration

Community/channel/hub records, visibility and post-visibility settings, branding
attachments, admin memberships and boost-bot relationships.

Target gem: Undecided. State: implemented models; full dashboard workflow is outside this inventory.

Sources: [community.rb](../../app/models/newsmast_mastodon/community.rb),
[community_admin.rb](../../app/models/newsmast_mastodon/community_admin.rb).
Dependencies: existing community tables, accounts, attachment storage and dashboard data.
Verification: [community_spec.rb](../../spec/models/newsmast_mastodon/community_spec.rb),
[community_admin_spec.rb](../../spec/models/newsmast_mastodon/community_admin_spec.rb);
confirm schema ownership and access policy, not just model loading.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### COMMUNITY-02: Community Content Rules and Channel Reblogging

Community hashtags, keyword rules, post/content types and channel-directed reblog
processing, with related background execution.

Target gem: Undecided. State: implemented; requires community data/configuration.

Sources: [community_hashtag.rb](../../app/models/newsmast_mastodon/community_hashtag.rb),
[community_filter_keyword.rb](../../app/models/newsmast_mastodon/community_filter_keyword.rb),
[community_post_type.rb](../../app/models/newsmast_mastodon/community_post_type.rb),
[content_type.rb](../../app/models/newsmast_mastodon/content_type.rb),
[reblog_channels_service.rb](../../app/services/newsmast_mastodon/reblog_channels_service.rb).
Dependencies: community/admin models, host post hooks, reblog worker and filter semantics.
Verification: [reblog_channels_service_spec.rb](../../spec/services/newsmast_mastodon/reblog_channels_service_spec.rb);
check matching and nonmatching posts, visibility and duplicate reblogs.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### COMMUNITY-03: Starter-Pack Discovery

List starter-pack channels and retrieve pack details from the configured JSON data.

Target gem: Gem B (`patchwork_extensions`). State: extracted; Gem A routes disabled
at cutover (2026-10-08); host-mode request specs pass.

Gem A sources (disabled, marked `GEM_SPLIT[COMMUNITY-03]`; remove after the
verification window):
[channels_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/channels_controller.rb),
[config/routes.rb](../../config/routes.rb) (`resources :channels` block, commented out),
[config/data](../../config/data).

Gem B sources (sibling repo `patchwork_extensions`):
[channels_controller.rb](../../../patchwork_extensions/app/controllers/patchwork_extensions/api/v1/channels_controller.rb),
[starter_pack_data.rb](../../../patchwork_extensions/app/services/patchwork_extensions/starter_pack_data.rb),
[engine.rb](../../../patchwork_extensions/lib/patchwork_extensions/engine.rb),
[routes.rb](../../../patchwork_extensions/config/routes.rb),
[config/data](../../../patchwork_extensions/config/data).

Dependencies: data-file packaging (Gem B gemspec `spec.files` includes `config/**/*`),
configured namespace and response caching. The host Gemfile loads both gems from
local paths during the split (`gem "newsmast_mastodon", path: "../newsmast_mastodon(patchwork)"`
and `gem "patchwork_extensions", path: "../patchwork_extensions"`).
Verification: [channels_spec.rb](../../../patchwork_extensions/spec/requests/patchwork_extensions/api/v1/channels_spec.rb)
(host-mode: list/detail, missing files, unknown packs, auth, source fallback) and
[starter_pack_data_spec.rb](../../../patchwork_extensions/spec/services/patchwork_extensions/starter_pack_data_spec.rb)
(cache invalidation). Evidence recorded in
[gem-split-implementation-log.md](../../../patchwork_extensions/docs/development/gem-split-implementation-log.md).
Cutover: DONE (2026-10-08) — Gem A routes block commented out; Gem B engine mounts at
`/` via `routes.prepend` (Mastodon's `*unmatched_route` catch-all requires prepend).

- [x] Assigned
- [x] Migrated
- [x] Verified

### COMMUNITY-04: Waitlist and Invitation State (removed)

Waitlist records, invitation codes, channel/hub type and confirmation-time usage
handling. Do not infer a complete invitation-management API from the model alone.

Target gem: Undecided. State: implemented model and confirmation integration.

Sources: [wait_list.rb](../../app/models/newsmast_mastodon/wait_list.rb),
[custom_passwords_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/custom_passwords_controller.rb).
Dependencies: existing waitlist table and account confirmation policy.
Verification: [wait_list_spec.rb](../../spec/models/newsmast_mastodon/wait_list_spec.rb);
check invalid/used codes and each configured registration mode.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

## External Boosting

### BOOST-01: Custom Boost-Bot Status Operations

Add/remove custom boost-bot statuses and call a configured remote bot service.

Target gem: Gem B (`patchwork_extensions`). State: extracted; Gem A routes
disabled at cutover (2026-10-28); host-mode request specs pass (9 examples,
0 failures; full Gem B suite 71 examples, 0 failures; standalone 71 examples,
0 failures, 62 pending).

Gem A sources (disabled, marked `GEM_SPLIT[BOOST-01]`; remove after the
verification window):
[custom_boost_bot_status_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/custom_statuses/custom_boost_bot_status_controller.rb),
[config/routes.rb](../../config/routes.rb) (`namespace :custom_statuses` block,
commented out). The Gem A request spec was deleted at cutover.

Gem A source retained (still active, marked `GEM_SPLIT[BOOST-01]`):
[custom_boost_bot_service.rb](../../app/services/newsmast_mastodon/custom_boost_bot_service.rb)
remains because `NewsmastMastodon::ReblogChannelsWorker` (COMMUNITY-02, not yet
assigned) calls it; pointing the worker at Gem B would be a Gem A -> Gem B
reverse dependency. The service was duplicated into Gem B instead (same
treatment as FEED-02's CustomTimelineService). Remove Gem A's copy when
COMMUNITY-02/BOOST-02 migrate.

Gem B sources (sibling repo `patchwork_extensions`):
[custom_boost_bot_status_controller.rb](../../../patchwork_extensions/app/controllers/patchwork_extensions/api/v1/custom_statuses/custom_boost_bot_status_controller.rb),
[custom_boost_bot_service.rb](../../../patchwork_extensions/app/services/patchwork_extensions/custom_boost_bot_service.rb),
[routes.rb](../../../patchwork_extensions/config/routes.rb).

Dependencies: host Search/SearchService/REST::SearchSerializer, Doorkeeper
application lookup, Status, and the FEED-02 `CustomTimelineService` (already in
Gem B; both copies write the same `feed:mix_channel_local_timeline` Redis key).
Remote credentials stay per-username ENV vars read by the service. No gem-owned
tables, workers, Redis keys or settings beyond the FEED-02 timeline key.
Flagged for follow-up security review: both endpoints authenticate with
`client_id`/`client_secret` in the POST body — any valid Doorkeeper application
credentials can add/remove boost-bot timeline entries, with no user or admin
check; the Gem A contract is preserved unchanged.
Verification: [custom_boost_bot_status_spec.rb](../../../patchwork_extensions/spec/requests/patchwork_extensions/api/v1/custom_statuses/custom_boost_bot_status_spec.rb)
(host-mode: credential validation, missing params, no-match 404, add/remove
timeline writes, unknown-id 404) and
[custom_boost_bot_service_spec.rb](../../../patchwork_extensions/spec/services/patchwork_extensions/custom_boost_bot_service_spec.rb)
(standalone-capable: remote POST contract). Evidence recorded in
[gem-split-implementation-log.md](../../../patchwork_extensions/docs/development/gem-split-implementation-log.md).
Cutover: DONE (2026-10-28) — Gem A routes block commented out.

- [x] Assigned
- [x] Migrated
- [x] Verified

### BOOST-02: Remote Boost and Reblog Delivery

Configured post boosting, Lambda integration and HTTP status-search/reblog helpers.
Some helper services require a call-site/deployment check before extraction.

Target gem: Undecided. State: configuration-dependent; individual helper usage needs confirmation.

Sources: [boost_post_service.rb](../../app/services/newsmast_mastodon/boost_post_service.rb),
[boost_lamda_newsmast_service.rb](../../app/services/newsmast_mastodon/boost_lamda_newsmast_service.rb),
[reblog_post_service.rb](../../app/services/newsmast_mastodon/reblog_post_service.rb),
[search_post_service.rb](../../app/services/newsmast_mastodon/search_post_service.rb),
[reblog_request_service.rb](../../app/services/newsmast_mastodon/reblog_request_service.rb),
[fetch_admin_access_token_service.rb](../../app/services/newsmast_mastodon/fetch_admin_access_token_service.rb),
[update_channel_name_services.rb](../../app/services/newsmast_mastodon/update_channel_name_services.rb).
Dependencies: configured remote instances, bot credentials, StatusConcern callbacks and workers.
Verification: [boost_post_service_spec.rb](../../spec/services/newsmast_mastodon/boost_post_service_spec.rb),
[boost_lamda_newsmast_service_spec.rb](../../spec/services/newsmast_mastodon/boost_lamda_newsmast_service_spec.rb);
check disabled mode, remote failures and duplicate delivery.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

## Moderation and Search

### MOD-01: Keyword Filters and Banning

Content/spam keyword groups, content/hashtag matching and status, account and tag
ban processing, including asynchronous enforcement.

Target gem: Undecided. State: implemented; policy-data-dependent.

Sources: [keyword_filter.rb](../../app/models/newsmast_mastodon/keyword_filter.rb),
[keyword_filter_group.rb](../../app/models/newsmast_mastodon/keyword_filter_group.rb),
[ban_status_service.rb](../../app/services/newsmast_mastodon/ban_status_service.rb),
[tag_concern.rb](../../app/models/newsmast_mastodon/concerns/tag_concern.rb).
Dependencies: server settings, ban columns, Redis exclusion sets, Sidekiq and indexing.
Verification: [ban_status_service_spec.rb](../../spec/services/newsmast_mastodon/ban_status_service_spec.rb),
[tag_concern_spec.rb](../../spec/models/concerns/tag_concern_spec.rb);
check local/remote posts, tags, accounts and removal of stale exclusions.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### MOD-02: Filtered Feeds, Search and Account Status Queries

Apply custom exclusions to feeds and status/account/tag search; extend account
status query options for reblogs, original/direct posts and channel boosts.

Target gem: Undecided. State: implemented.

Sources: [feed_service.rb](../../app/services/newsmast_mastodon/feed_service.rb),
[feed_concern.rb](../../app/models/newsmast_mastodon/concerns/feed_concern.rb),
[public_feed_concern.rb](../../app/models/newsmast_mastodon/concerns/public_feed_concern.rb),
[search_service_extension.rb](../../app/services/newsmast_mastodon/overrides/search_service_extension.rb),
[account_search_service_extension.rb](../../app/services/newsmast_mastodon/overrides/account_search_service_extension.rb),
[tag_search_service.rb](../../app/services/newsmast_mastodon/concerns/tag_search_service.rb),
[extended_account_statuses_filter.rb](../../app/lib/newsmast_mastodon/overrides/extended_account_statuses_filter.rb).
Dependencies: MOD-01, community admins, server settings and installed search indexes.
Verification: [feed_service_spec.rb](../../spec/services/newsmast_mastodon/feed_service_spec.rb),
[public_feed_concern_spec.rb](../../spec/models/concerns/public_feed_concern_spec.rb);
check exclusions across API surfaces and pagination after filtering.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### MOD-03: Federation Filters and Discovery Defaults

Settings-based domain exclusions, automatic search opt-out and automatic Bluesky
bridge preference for new users. Setting a bridge preference is not a bridge implementation.

Target gem: Undecided. State: configuration-dependent.

Sources: [user_concern.rb](../../app/models/newsmast_mastodon/concerns/user_concern.rb),
[account_search_concern.rb](../../app/models/newsmast_mastodon/concerns/account_search_concern.rb),
[status_concern.rb](../../app/models/newsmast_mastodon/concerns/status_concern.rb).
Dependencies: server/user settings, account discoverability/indexability and host bridge support.
Verification: [user_concern_spec.rb](../../spec/models/concerns/user_concern_spec.rb);
test absent settings, opted-out users and domain filtering without assuming federation delivery is blocked.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### MOD-04: Moderation Maintenance and Import Tasks

Update/preview/reset banned account state, update banned tags, and import domain
and username blocks.

Target gem: Undecided. State: implemented operational tasks.

Sources: [content_filters.rake](../../lib/tasks/newsmast_mastodon/content_filters.rake),
[domain_block.rake](../../lib/tasks/newsmast_mastodon/domain_block.rake),
[username_blocks.rake](../../lib/tasks/newsmast_mastodon/username_blocks.rake).
Dependencies: configured input data, host moderation models, filter policy and indexes.
Verification: use isolated fixtures/databases to check import validation, repeatability
and reset effects; do not run these tasks against production to validate the split.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

## Notifications

### NOTIFY-01: Device Tokens and Push Delivery

Register/revoke tokens, reset tokens by platform, read/update mute state and deliver
custom Mastodon notifications through Firebase.

Target gem: Undecided. State: implemented token API; configuration-dependent delivery.

Sources: [notification_tokens_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/notification_tokens_controller.rb),
[notification_token.rb](../../app/models/newsmast_mastodon/notification_token.rb),
[firebase_notification_service.rb](../../app/services/newsmast_mastodon/firebase_notification_service.rb),
[custom_notification_service.rb](../../app/services/newsmast_mastodon/custom_notification_service.rb),
[notify_service_extension.rb](../../app/services/newsmast_mastodon/overrides/notify_service_extension.rb).
Dependencies: token migration, provider credentials, mute policy and host notification hooks.
Verification: [notification_tokens_spec.rb](../../spec/requests/newsmast_mastodon/api/v1/notification_tokens_spec.rb),
[firebase_notification_service_spec.rb](../../spec/services/newsmast_mastodon/firebase_notification_service_spec.rb);
check supported delivery platforms, revoked tokens and provider failures.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### NOTIFY-02: Notification Query and Mention Filters

Extend v1/v2 notification queries with private/direct mention filtering and grouped
notification handling.

Target gem: Undecided. State: implemented.

Sources: [notification_concern.rb](../../app/models/newsmast_mastodon/concerns/notification_concern.rb),
[notification_v1_extended_controller.rb](../../app/lib/newsmast_mastodon/overrides/notification_v1_extended_controller.rb),
[notification_extended_controller.rb](../../app/lib/newsmast_mastodon/overrides/notification_extended_controller.rb).
Dependencies: host notification types, pagination and grouped response contract.
Verification: [notification_concern_spec.rb](../../spec/models/concerns/notification_concern_spec.rb);
also exercise both API versions and combinations of mention filters.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### NOTIFY-03: Email Notification Preferences

Read/update email-notification settings and apply explicitly configured defaults
for new users. Mail branding is tracked under UI-01.

Target gem: Undecided. State: implemented.

Sources: [email_settings_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/patchwork/email_settings_controller.rb),
[email_notification_attributes_concern.rb](../../app/models/newsmast_mastodon/concerns/email_notification_attributes_concern.rb),
[user_concern.rb](../../app/models/newsmast_mastodon/concerns/user_concern.rb).
Dependencies: host user settings and environment-controlled defaults.
Verification: [email_settings_spec.rb](../../spec/requests/newsmast_mastodon/api/v1/email_settings_spec.rb);
confirm absent configuration preserves host defaults and updates remain user-scoped.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

## Publishing Integrations

### CMS-01: Ghost and WordPress Article Notifications

Webhook authentication and payload handling, asynchronous article notifications,
and account-level article/Leicester notification preferences. Ghost webhook
creation/update/deletion is also exposed through maintenance tasks.

Target gem: Undecided. State: configuration-dependent; not safe to split without
NOTIFY-01 and settings ownership.

Gem A sources (retained pending ownership review):
[webhooks_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/webhooks_controller.rb),
[ghost_notification_service.rb](../../app/services/newsmast_mastodon/ghost_notification_service.rb),
[article_notification_service.rb](../../app/services/newsmast_mastodon/article_notification_service.rb),
[patchwork_settings_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/accounts/patchwork_settings_controller.rb),
[ghost.rake](../../lib/tasks/newsmast_mastodon/ghost.rake).
Dependencies: CMS configuration, host allowlisting, article workers, app settings and NOTIFY-01.
Verification: [webhooks_spec.rb](../../spec/requests/webhooks_spec.rb),
[ghost_notification_service_spec.rb](../../spec/services/newsmast_mastodon/ghost_notification_service_spec.rb),
[article_notification_service_spec.rb](../../spec/services/newsmast_mastodon/article_notification_service_spec.rb);
check invalid signatures, malformed payloads, muted recipients and repeat delivery.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### CMS-02: Ghost Newsletter Subscription

Find/create a Ghost member and update subscription state through the account API.

Target gem: Gem B (`patchwork_extensions`). State: extracted; Gem A route disabled
at cutover (2026-10-15); host-mode request spec added for the split path.

Gem A source (disabled, marked `GEM_SPLIT[CMS-02]`; remove after the verification window):
[ghost_subscriptions_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/accounts/ghost_subscriptions_controller.rb),
[config/routes.rb](../../config/routes.rb) (`post "subscribe_leicester"` route,
commented out).

Gem B source (sibling repo `patchwork_extensions`):
[ghost_subscriptions_controller.rb](../../../patchwork_extensions/app/controllers/patchwork_extensions/api/v1/accounts/ghost_subscriptions_controller.rb),
[routes.rb](../../../patchwork_extensions/config/routes.rb).
Dependencies: Ghost member API, authenticated account identity and external configuration; no gem-owned tables, workers, Redis keys or settings.
Verification: [ghost_subscriptions_spec.rb](../../../patchwork_extensions/spec/requests/patchwork_extensions/api/v1/accounts/ghost_subscriptions_spec.rb)
(host-mode: create member for new email, require auth). Evidence recorded in
[gem-split-implementation-log.md](../../../patchwork_extensions/docs/development/gem-split-implementation-log.md).
Cutover: DONE (2026-10-15) — Gem A route commented out.

- [x] Assigned
- [x] Migrated
- [x] Verified

## Relays

### RELAY-01: Relay Management, Sync and Incoming Content

Relay add/remove endpoints, synchronization against configured relay domains and
an incoming ActivityPub Create extension. Domain feed reading is FEED-03.

Target gem: Undecided. State: configuration-dependent; automatic scheduler registration disabled.

Sources: [relays_controller.rb](../../app/controllers/newsmast_mastodon/api/v1/relays_controller.rb),
[sync_custom_relays_service.rb](../../app/services/newsmast_mastodon/sync_custom_relays_service.rb),
[custom_relay_config.rb](../../lib/newsmast_mastodon/custom_relay_config.rb),
[activity_create_relay_extension.rb](../../app/services/newsmast_mastodon/overrides/activity_create_relay_extension.rb),
[relay_env_sync_worker.rb](../../app/workers/newsmast_mastodon/relay_env_sync_worker.rb).
Dependencies: host relay state machine, authorization, ActivityPub, Redis and scheduling (INFRA-02).
Verification: [relays_spec.rb](../../spec/requests/relays_spec.rb),
[activity_create_relay_extension_spec.rb](../../spec/services/newsmast_mastodon/overrides/activity_create_relay_extension_spec.rb);
check ownership, repeat sync and unconfigured/untrusted domains.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

## Settings and Presentation

### SETTINGS-01: Server, User and App-Scoped Settings

Hierarchical server settings, user-setting relationships and account/app-scoped
JSON settings for branded applications. Consumers include filtering, signup,
community behavior and article notification preferences.

Target gem: Undecided. State: implemented models and feature-specific consumers.

Sources: [server_setting.rb](../../app/models/newsmast_mastodon/server_setting.rb),
[user_server_setting.rb](../../app/models/newsmast_mastodon/user_server_setting.rb),
[patchwork_setting.rb](../../app/models/newsmast_mastodon/patchwork_setting.rb),
[patchwork_helper.rb](../../app/helpers/patchwork_helper.rb).
Dependencies: database ownership, dashboard-managed setting names and all consuming features.
Verification: [server_setting_spec.rb](../../spec/models/newsmast_mastodon/server_setting_spec.rb),
[patchwork_setting_spec.rb](../../spec/models/newsmast_mastodon/patchwork_setting_spec.rb);
check defaults, missing records and app/account isolation.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### UI-01: Mail Branding and Product Helpers

Mail brand color, header/footer logos, mailer layouts and product/channel helper
conditions. These are specific presentation extensions, not a complete theme editor.

Target gem: Undecided. State: implemented; settings/asset-dependent.

Sources: [brand_color_helper.rb](../../app/helpers/brand_color_helper.rb),
[logo_helper.rb](../../app/helpers/logo_helper.rb),
[mo_me_helper.rb](../../app/helpers/mo_me_helper.rb),
[non_channel_helper.rb](../../app/helpers/non_channel_helper.rb),
[mailer_overrides.rb](../../config/initializers/mailer_overrides.rb),
[mailer_views.rb](../../config/initializers/mailer_views.rb),
[mailer.html.haml](../../app/views/layouts/mailer.html.haml).
Dependencies: host settings/uploads, helper inclusion, templates and packaged images/styles.
Verification: [brand_color_helper_spec.rb](../../spec/helpers/brand_color_helper_spec.rb),
[non_channel_helper_spec.rb](../../spec/helpers/non_channel_helper_spec.rb);
render emails with and without custom branding.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### UI-02: Compose, Status Display and Admin View Overrides

Bundled compose actions/reducer/form, federated dropdown, detailed-status component
and admin status partial. Treat this as the UI delivery portion of post features,
not an assertion that every upstream component behavior is a new gem feature.

Target gem: Undecided. State: source implemented; host installation/build required.

Sources: [compose_form.jsx](../../app/javascript/newsmast_mastodon/mastodon/features/compose/components/compose_form.jsx),
[federated_dropdown.jsx](../../app/javascript/newsmast_mastodon/mastodon/features/compose/components/federated_dropdown.jsx),
[detailed_status.tsx](../../app/javascript/newsmast_mastodon/mastodon/features/status/components/detailed_status.tsx),
[_status.html.haml](../../app/views/admin/shared/_status.html.haml),
[install.rake](../../lib/tasks/newsmast_mastodon/install.rake).
Dependencies: host frontend build, matching Mastodon components and POST/MEDIA APIs.
Verification: perform host frontend tests and desktop/mobile rendering checks after
extraction; backend specs and override baselines do not prove frontend behavior.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### UI-03: Mobile App Association Endpoints

Serve Apple app-site association and Android asset-links responses for deep links.

Target gem: Gem B (`patchwork_extensions`). State: extracted; Gem A routes
disabled at cutover (2026-10-13); host-mode request specs pass (6 examples,
0 failures; full Gem B suite 47 examples, 0 failures).

Gem A sources (disabled, marked `GEM_SPLIT[UI-03]`; remove after the
verification window):
[deep_links_controller.rb](../../app/controllers/newsmast_mastodon/well_known/deep_links_controller.rb),
[deep_links.rb](../../config/initializers/deep_links.rb),
[config/routes.rb](../../config/routes.rb) (`.well-known` scope block,
commented out).

Gem B sources (sibling repo `patchwork_extensions`):
[deep_links_controller.rb](../../../patchwork_extensions/app/controllers/patchwork_extensions/well_known/deep_links_controller.rb),
[routes.rb](../../../patchwork_extensions/config/routes.rb).

Dependencies: the four ENV vars (`IOS_APP_ID`, `IOS_DEEPLINK_PATHS`,
`ANDROID_PACKAGE_NAME`, `ANDROID_SHA256_CERT_FINGERPRINTS`) read at request
time; public well-known routes; no gem-owned tables, workers, Redis keys or
settings. Gem A's `config/initializers/deep_links.rb` only wrote
`config.x.deep_links`, which has no consumers; it was not copied to Gem B.
Verification: [deep_links_spec.rb](../../../patchwork_extensions/spec/requests/patchwork_extensions/well_known/deep_links_spec.rb)
(host-mode: success payloads, default/custom iOS paths, multi-fingerprint
Android, missing-config 404s, public caching). Evidence recorded in
[gem-split-implementation-log.md](../../../patchwork_extensions/docs/development/gem-split-implementation-log.md).
Cutover: DONE (2026-10-13) — Gem A routes block commented out.

- [x] Assigned
- [x] Migrated
- [x] Verified

## Shared Infrastructure

These are extraction work items, not additional user-facing features. Move shared
code according to the eventual feature decisions, not its current filename.

### INFRA-01: Engine Initialization and Runtime Extensions

Automatic root route mounting, migration-path registration, reload-time model,
controller and service extensions, and authentication guards for admin dashboard
and reports controllers.

Target gem: Undecided. State: implemented.

Sources: [engine.rb](../../lib/newsmast_mastodon/engine.rb),
[prepend_concerns.rb](../../config/initializers/prepend_concerns.rb),
[routes.rb](../../config/routes.rb).
Dependencies: host Mastodon constants and initialization order. Separate mixed
feature callbacks and associations without introducing reverse gem dependencies.
Verification: boot/reload with the intended gem combinations and confirm routes
and extensions register exactly once. The Chewy replacement block in this
initializer is commented out; do not treat it as active index replacement.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### INFRA-02: Host Compatibility and Optional Scheduling

The engine compares the host Mastodon version against gem metadata, warns outside
production and aborts production startup on a mismatch. Its relay-sync scheduler
registration is commented out, independently of whether the sync service exists.

Target gem: Undecided. State: implemented version guard; disabled scheduler registration.

Source: [engine.rb](../../lib/newsmast_mastodon/engine.rb).
Dependencies: gem metadata, host version, Sidekiq and deployment-owned scheduling.
Verification: test supported/unsupported host versions and decide explicitly who
registers any periodic relay job. Do not assume periodic sync is enabled.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### INFRA-03: Schema Ownership and Upgrade Compatibility

Assign migrations and existing table ownership for drafts/media, device tokens,
settings, reactions, account/status ban flags, local-only posts and alt-text
preferences. Account for historical add/remove migrations and host compatibility
columns for quote edits, fetched replies and announcement notifications; these
columns alone are not standalone new product features.

Target gem: Undecided. State: implemented migrations; external table ownership needs confirmation.

Sources: [db/migrate](../../db/migrate),
[migration_compatibility.rb](../../lib/newsmast_mastodon/migration_compatibility.rb).
Dependencies: host schema, migration versions/foreign keys and community/waitlist/filter
tables referenced by models but not necessarily created by this gem's migrations.
Verification: [migrations_spec.rb](../../spec/integration/migrations_spec.rb),
[migration_guard_spec.rb](../../spec/compatibility/migration_guard_spec.rb);
test fresh installation and upgrade of an existing deployment without replaying or
losing already-applied migrations/data. Record a rollback strategy before migration.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### INFRA-04: Host-Copied Assets and Search Indexes

Installation copies/transforms Chewy indexes and copies frontend/admin view
overrides into the host, then writes an installation marker checked at startup.
This is distinct from automatic engine route/migration registration.

Target gem: Undecided. State: implemented installer; host filesystem changes required.

Sources: [install.rake](../../lib/tasks/newsmast_mastodon/install.rake),
[installation_guard.rb](../../lib/newsmast_mastodon/installation_guard.rb),
[app/chewy/newsmast_mastodon](../../app/chewy/newsmast_mastodon),
[override_baselines.yml](../../config/override_baselines.yml).
Dependencies: writable host paths, build pipeline, upstream override versions and index names.
Verification: [installation_guard_spec.rb](../../spec/lib/newsmast_mastodon/installation_guard_spec.rb);
test installation, rebuild, reindex requirements and upgrade/uninstall handling.
The runtime index replacement block is disabled, but the installer still copies
indexes; do not mistake the disabled block for an absent search customization.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### INFRA-05: Jobs, Redis, Configuration and Shared Callbacks

Keep background worker class names/queues, in-flight jobs, Redis feed/exclusion
keys, environment configuration and shared model associations compatible during
the transition. Assign each worker with its owning feature, not as a third gem.

Target gem: Undecided. State: implemented shared integration points.

Sources: [app/workers/newsmast_mastodon](../../app/workers/newsmast_mastodon),
[status_concern.rb](../../app/models/newsmast_mastodon/concerns/status_concern.rb),
[account_concern.rb](../../app/models/newsmast_mastodon/concerns/account_concern.rb),
[user_concern.rb](../../app/models/newsmast_mastodon/concerns/user_concern.rb).
Dependencies: feature-owned tables, provider clients and deployments with old queued jobs.
Verification: [prepend_concerns_spec.rb](../../spec/integration/prepend_concerns_spec.rb)
is a registration starting point; additionally test retries, job deserialization,
disabled features, missing optional configuration and cross-gem dependency direction.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified

### INFRA-06: Packaging, Compatibility Tests and Release Ownership

Assign gem dependencies, public namespaces, bundled data/assets/locales, specs,
fixtures, host harness, override drift checks and release documentation to the two
gems once their names and feature boundaries are decided.

Target gem: Undecided. State: existing gem infrastructure; split design undecided.

Sources: [newsmast_mastodon.gemspec](../../newsmast_mastodon.gemspec),
[ci.yml](../../.github/workflows/ci.yml),
[bin/check-override-drift](../../bin/check-override-drift),
[spec/README.md](../../spec/README.md), [RELEASE.md](../../RELEASE.md).
Dependencies: supported Mastodon versions, host services and installable gem artifacts.
Verification: [version_sync_spec.rb](../../spec/compatibility/version_sync_spec.rb);
run each feature's meaningful tests in the intended host, build/install both gems,
check all supported gem combinations and document installation/upgrade steps.

- [ ] Assigned
- [ ] Migrated
- [ ] Verified
