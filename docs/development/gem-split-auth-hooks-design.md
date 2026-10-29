# Signup/Login Hook Refactor Design

Date: 2026-10-14. Status: proposed, not implemented.

Purpose: remove hardcoded cross-feature calls from Gem A's auth/signup concerns
so AUTH-01, AUTH-03 and AUTH-04 can move to Gem B (`patchwork_extensions`)
without a Gem A → Gem B dependency. Follows the split proposal rule: Gem B
extends Gem A via configuration hooks, never by monkeypatching Gem A classes.

## 1. Current coupling (why these features are blocked)

### `Concerns::AccountsCreation#create` (prepended onto `Api::V1::AccountsController`)

One method performs five custom behaviors with hardcoded constants:

| Call site | Feature | Blocker |
| --- | --- | --- |
| `NewsmastMastodon::CivicrmMembershipCheckService.new(email).call` | AUTH-04 | Gem A constant; gates every signup |
| `membership_fields_attributes(result.user_groups)` | AUTH-04 | profile fields derived from CRM data |
| `create_community_admin` | COMMUNITY-01 | gated by `patchwork_community_admin_exist?` |
| `generate_opt_token` → `CustomPasswordsMailer` | AUTH-01 | already guarded by `defined?(CustomPasswordsMailer)` |
| `enqueue_role_assignment` → `CivicrmRoleAssignmentWorker` | AUTH-04 | gated by `CSID_ROLE_ASSIGNMENT_ENABLED` |

If AUTH-04 moves to Gem B as-is, Gem A code raises `NameError` on every
registration (the membership check runs unconditionally, unlike the
`defined?`-guarded OTP mailer).

### `Concerns::CustomAuthenticationBehavior#create` (prepended onto `Auth::TokensController` / `OAuth::TokensController`)

Dispatches to `LoginService` variants with a hardcoded
`LOCAL_DOMAIN == "thebristolcable.social"` check (AUTH-03). Proprietary
per-deployment login policy embedded in a core auth override.

### `Concerns::OverridePrepareNewUser` (prepended onto `User`)

Auto-follow (AUTH-05) via `AUTO_FOLLOW_ENABLED`/`AUTO_FOLLOW_ACCOUNTS` ENV.
Self-contained already; listed for completeness — it can stay in Gem A or move
behind a hook, but it is not a blocker.

## 2. Hook registry in Gem A

Add a small configuration object to Gem A. Gem A ships with **empty defaults**
(signup behaves like vanilla Mastodon); Gem B registers implementations in an
engine initializer.

```ruby
# lib/newsmast_mastodon/signup_hooks.rb
module NewsmastMastodon
  class SignupHooks
    # Gate: callable(email:) -> result responding to valid?, error_message,
    # user_groups. nil result (no gate registered) means allow.
    attr_accessor :registration_gate

    # Post-signup handlers, run in registration order after a successful
    # AppSignUpService call. Each is callable(context) where context has
    # user:, account:, token:, params:, request:.
    def post_signup_handlers
      @post_signup_handlers ||= []
    end

    # Profile-fields provider: callable(gate_result) -> fields_attributes
    # hash or nil. Only consulted when a gate returned a result.
    attr_accessor :profile_fields_provider
  end

  class << self
    def signup_hooks
      @signup_hooks ||= SignupHooks.new
    end

    # Test helper; also usable by hosts that need a clean slate.
    def reset_signup_hooks!
      @signup_hooks = SignupHooks.new
    end
  end
end
```

Same pattern for the login path:

```ruby
# lib/newsmast_mastodon/login_hooks.rb
module NewsmastMastodon
  class LoginHooks
    # Strategy picker: callable(params:, request:) -> symbol or callable.
    # nil means default (channel/non-channel dispatch stays in Gem A).
    attr_accessor :strategy_resolver
  end
end
```

### Registration rules (important)

- Register hooks in an engine `initializer` block, **never** inside
  `config.to_prepare` — `to_prepare` runs on every reload and would append
  duplicate handlers. If any registration must happen in `to_prepare`, call
  `reset_signup_hooks!` (or use idempotent `handler unless include?`) first.
- Hooks are plain callables (lambda/class with `.call`), so Gem B never needs
  to prepend or reopen Gem A classes.
- Hook exceptions: post-signup handlers wrap each call in
  `rescue StandardError` + `Rails.logger.error`, matching the existing
  `enqueue_role_assignment` behavior — a failing handler must not roll back a
  completed signup. The **gate** is the exception: gate errors propagate as
  today (signup refused).

## 3. Refactored call sites

### `accounts_creation.rb` (stays in Gem A)

```ruby
def create
  gate_result = run_registration_gate
  return render_membership_error(gate_result.error_message) if gate_result && !gate_result.valid?

  params_with_reason = account_params.merge(reason: "Signing up via #{ENV.fetch('LOCAL_DOMAIN', nil)} App")
  fields = run_profile_fields_provider(gate_result)
  params_with_reason[:fields_attributes] = fields if fields.present?
  token    = AppSignUpService.new.call(doorkeeper_token.application, request.remote_ip, params_with_reason)
  response = Doorkeeper::OAuth::TokenResponse.new(token)

  headers.merge!(response.headers)
  self.response_body = response.body.to_json
  self.status        = response.status

  run_post_signup_hooks(token)
rescue ActiveRecord::RecordInvalid => e
  render json: ValidationErrorFormatter.new(e, 'account.username': :username, 'invite_request.text': :reason).as_json,
         status: 422
end

private

def run_registration_gate
  gate = NewsmastMastodon.signup_hooks.registration_gate
  gate&.call(email: account_params[:email])
end

def run_post_signup_hooks(token)
  context = SignupContext.new(
    user: User.find_by(id: token.resource_owner_id),
    account: Account.find_by(id: token.resource_owner_id),
    token: token, params: account_params, request: request
  )
  NewsmastMastodon.signup_hooks.post_signup_handlers.each do |handler|
    begin
      handler.call(context)
    rescue StandardError => e
      Rails.logger.error("Signup hook #{handler.inspect} failed: #{e.class}")
    end
  end
end
```

Notes:

- With no hooks registered, behavior is vanilla-Mastodon signup — this is the
  Gem A-on-vanilla install story.
- `SignupContext` is a small `Data`/`Struct` in Gem A; keep its fields stable —
  it becomes a public API between the gems.
- The current behavior ordering is preserved: gate first (422 on failure),
  then signup, then side effects. The OTP mailer's
  `defined?(CustomPasswordsMailer)` guard disappears — the hook simply isn't
  registered when the mailer isn't loaded.

### `custom_authentication_behavior.rb` (stays in Gem A)

```ruby
strategy = NewsmastMastodon.login_hooks.strategy_resolver&.call(params: oauth_params, request: request)
error_message = if strategy
  strategy.call # e.g. Gem B's Bristol Cable lambda
elsif is_non_channel?
  NewsmastMastodon::LoginService.new(oauth_params).non_channel_login || nil
else
  NewsmastMastodon::LoginService.new(oauth_params).channel_login || nil
end
```

The hardcoded `thebristolcable.social` check moves into Gem B's resolver:

```ruby
# patchwork_extensions/lib/patchwork_extensions/engine.rb
initializer "patchwork_extensions.auth_hooks" do
  NewsmastMastodon.login_hooks.strategy_resolver = lambda do |params:, request:|
    if ENV.fetch("LOCAL_DOMAIN", nil) == "thebristolcable.social" || Rails.env.development?
      -> { PatchworkExtensions::BristolcableLoginService.new(params).call }
    end
  end
end
```

## 4. Feature mapping after the refactor

| Current behavior | Hook | New owner |
| --- | --- | --- |
| CiviCRM membership gate + error message | `registration_gate` | Gem B (AUTH-04) |
| Membership-derived profile fields | `profile_fields_provider` | Gem B (AUTH-04) |
| `CivicrmRoleAssignmentWorker` enqueue | `post_signup_handlers` | Gem B (AUTH-04); keep the worker class name unchanged for in-flight jobs (INFRA-05) |
| OTP token + `CustomPasswordsMailer` | `post_signup_handlers` | Gem B (AUTH-01) — moves with controller + mailer |
| `create_community_admin` | `post_signup_handlers` | decided with COMMUNITY-01 ownership |
| Bristol Cable login dispatch | `strategy_resolver` | Gem B (AUTH-03) |
| Auto-follow (`OverridePrepareNewUser`) | unchanged (ENV-driven) | Gem A (AUTH-05) — no cross-gem call |

## 5. Remaining blockers this design does NOT solve

- **AUTH-01 ↔ COMMUNITY-04 (waitlist):** `CustomPasswordsController` reads and
  writes `NewsmastMastodon::WaitList`. Decide waitlist table ownership
  (INFRA-03) before moving AUTH-01. If waitlist goes to Gem B too, the
  dependency is internal and fine; if it stays in Gem A, Gem B needs the
  `defined?`-style guarded lookup the controller already uses — acceptable but
  must be specced in both modes.
- **Doorkeeper reconfiguration (AUTH-02):** the
  `Doorkeeper.configuration.instance_eval` block in Gem A's engine is a global
  auth-stack change and stays in Gem A per the proposal (core override). Only
  the per-deployment login strategy moves.
- **Response-contract drift:** hook dispatch must preserve current status codes
  and payload shapes (422 validation format, 401 login errors, token response
  headers). Existing request specs are the contract; run them against Gem A
  with no hooks registered and with Gem B's hooks registered.

## 6. Migration sequence

1. Gem A: add `SignupHooks`/`LoginHooks`, refactor the two concerns, no
   behavior change (register current CiviCRM/OTP/community-admin logic as
   Gem A-internal default hooks temporarily). Run existing auth specs.
2. Gem A: remove the default registrations; Gem A now behaves as vanilla
   signup/login. Add specs for the no-hooks path.
3. Gem B: move CiviCRM services/worker/rake tasks (AUTH-04), register gate +
   profile-fields + role-assignment hooks. Host-mode request specs.
4. Gem B: move Bristol Cable service (AUTH-03), register resolver. Host-mode
   login specs (rejection, service failure, registration-required).
5. Gem B: move `CustomPasswordsController` + mailer (AUTH-01) once waitlist
   ownership is decided; register the OTP hook. Full OTP spec pass.
6. Cutover per checklist convention: comment out Gem A routes, mark sources
   `GEM_SPLIT[<id>]`, delete Gem A request specs, update
   `spec/routing/routes_spec.rb`, record evidence in Gem B's
   gem-split-implementation-log.md.

## 7. Test plan per step

- Hook registry unit specs: registration order, reload-safety (no duplicates),
  exception isolation for post-signup handlers, gate-error propagation.
- Gem A request specs: signup/login with zero hooks = vanilla contract.
- Gem B host-mode specs: same scenarios the current Gem A specs cover
  (`accounts_registration_membership_spec.rb`, `custom_passwords_spec.rb`,
  `login_service_spec.rb`), plus a boot check with only Gem A loaded to prove
  no `NameError`.
