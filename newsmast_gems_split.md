# Case: Splitting newsmast_mastodon into Two Gems

> Context document for AI-assisted development (GitHub Copilot).
> Use this file as project context when generating code for the gem extraction.

## 1. Background

- Repo: <https://github.com/patchwork-hub/newsmast_mastodon> — an extended/overridden fork of Mastodon (<https://github.com/mastodon/mastodon>).
- Goal: separate the fork's code into two gems and make the fork a thin host app, so upstream Mastodon merges are nearly conflict-free.

## 2. The Two Gems

| | **Gem A** (open source) | **Gem B** (private/undecided) |
| --- | --- | --- |
| Purpose | Overrides/extensions of Mastodon core features | Custom/proprietary features |
| Audience | Any Mastodon developer (installable on vanilla Mastodon) | Only us / our organization |
| Design constraint | Pure, self-contained Rails engine — zero dependence on our fork | Layers on top of Gem A |
| Dependency | Standalone | Depends on Gem A (never the reverse) |
| Versioning | SemVer + Mastodon compatibility matrix | Loose tracking of Gem A versions |
| License | AGPL-3.0 (required — it extends Mastodon) | TBD |

## 3. Core Architectural Rules

1. The fork stays thin (< ~50 lines diff vs upstream): only `Gemfile`, routes drawing, and config glue.
2. Never edit Mastodon classes in place. Overrides use `Module#prepend` + `config.to_prepare` inside the engine:

   ```ruby
   # gem_a/lib/gem_a/engine.rb
   module GemA
     class Engine < ::Rails::Engine
       initializer "gem_a.decorators" do
         config.to_prepare do
           Status.prepend GemA::StatusDecorator
           ApplicationController.prepend_view_path GemA::Engine.root.join("app/views")
         end
       end
     end
   end
   ```

3. One-way dependency only: Gem B → Gem A → Mastodon. Gem A has zero knowledge of Gem B.
4. Gem B extends Gem A via configuration hooks, never by monkeypatching Gem A classes.
5. Engine migrations ship with the gem and are installed via `rails gem_a:install:migrations`.

## 4. Gem A Must Work on Vanilla Mastodon

Gem A's installation steps for a third party must be exactly:

1. Add to Gemfile: `gem "gem_a", "~> 2.0"`
2. `bundle install`
3. `rails gem_a:install:migrations && rails db:migrate`
4. Restart

Anything beyond this means the design needs rework. No reliance on glue code in our fork.

## 5. Branching Strategy

### Gem A (public)

- `main` — latest, tracks latest stable Mastodon
- `1.x-stable` — backports for older Mastodon series (e.g., Mastodon 4.2.x)
- Flow: `feature/x` → PR → `main`; hotfixes cherry-picked to stable branches
- Tags: SemVer (`v2.1.0`)

### Gem B (private)

- Trunk-based: `feature/x` → PR → `main`
- Tags loosely track Gem A versions

### Fork (host app)

- `main` merges upstream Mastodon release tags directly (thin app → rare conflicts)
- `Gemfile` pins: `gem "gem_a", "~> 2.1"` and `gem "gem_b", github: "<private>"`

## 6. Workflows

### Upstream sync (per Mastodon release)

```bash
git remote add upstream https://github.com/mastodon/mastodon
git fetch upstream
git checkout main
git merge v4.4.0          # fix conflicts — should only be Gemfile/routes/config
bundle update && rails db:migrate && rspec
git tag v4.4.0-newsmast.1
```

### CI

- **Gem A**: test matrix against multiple vanilla Mastodon versions (e.g., 4.2.x, 4.3.x); run Mastodon's own suite with the gem loaded. Weekly scheduled run against Mastodon `main` for early breakage warnings.
- **Gem B**: standard suite, run against latest Gem A.
- **Fork**: full Mastodon suite + both gems' suites after each upstream merge.

## 7. Open-Source Checklist for Gem A

- [ ] AGPL-3.0 license file (before first public commit)
- [ ] Final gem name/namespace (hard to rename later)
- [ ] README: install steps, compatibility matrix (gem version ↔ Mastodon version), contribution guide
- [ ] Neutral branding — no hardcoded product names, env vars, or defaults
- [ ] Issue templates for upstream-version combinations

## 8. Open Decisions

- [ ] Gem B: public or private repo?
- [ ] Must Gem B be installable standalone on vanilla Mastodon (independent of Gem A)? Default recommendation: keep it independent where cheap — preserves both options.

## 9. Guardrails for Copilot-Generated Code

- Never generate code that edits Mastodon core files directly — always engine decorators/`to_prepare`.
- Never add references to Gem B (or product-specific naming) inside Gem A.
- New engine features must include: engine migration, route inside the engine, and a test in the vanilla-Mastodon dummy app harness.
- Any override of a private/internal Mastodon API must be wrapped in a feature flag and reference the upstream commit/PR it depends on.
