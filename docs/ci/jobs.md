# CI Jobs

This repository uses multiple CI jobs for quality, compatibility, and security.

| Workflow | Job | Purpose | Requirements |
| --- | --- | --- | --- |
| `CI` | `changelog-policy` | Ensures changes that touch code/workflows update `CHANGELOG.md`. | Pull requests and pushes to main; passes without checking when the PR has the `no-changelog` label. |
| `CI` | `lint` | Runs RuboCop for style and static checks. | Ruby 3.3, 3.4, 4.0 matrix. |
| `CI` | `api-contract` | Verifies route/controller/Postman docs sync via `bundle exec rake api:verify`. | No external services required. |
| `CI` | `test` | Runs main RSpec suite (sqlite mode by default) and uploads coverage artifacts. | Redis service; Ruby 3.3, 3.4, 4.0 matrix. |
| `CI` | `test-postgres-subset` | Validates targeted model specs against real Postgres schema bootstrap. | Postgres + Redis services; Ruby 3.4. |
| `CI` | `compatibility` | Runs upgrade-safety and version-sync compatibility specs. | Ruby 3.4. |
| `CI` | `override-drift` | Compares the upstream files the gem overrides with upstream Mastodon at the gem's target version (`config/override_baselines.yml`). | Runs on every PR and push; no services. |
| `CI` | `host-integration` | Installs this checkout into upstream Mastodon at the target version, runs `newsmast_mastodon:install` and the gem's migrations, then runs the full spec suite in host mode. | Postgres + Redis services; host's Ruby version. Runs on every PR and push. |
| `CI` | `ci-ok` | Aggregates required CI jobs into one stable merge gate. | Runs after required CI jobs complete. |
| `Security` | `dependency-review` | Detects risky dependency changes. | Pull requests, and pushes to main (compares the commit before the push with the pushed commit). |
| `Security` | `bundler-audit` | Scans resolved gem dependencies against RubySec advisories. | PR, push to main, and weekly schedule. |
| `Security` | `lint-workflows` | Lints workflows and composite actions with `actionlint` and `zizmor`, including zizmor's online audits (impostor or mismatched action SHAs). | PR, push to main, and weekly schedule. |
| `Security` | `codeql` | Runs scheduled and event-driven Ruby CodeQL static analysis. | `security-events: write` permission. |

## Host integration

`host-integration` runs on every pull request and push to `main`, and is part
of `ci-ok`. By default it uses `mastodon/mastodon` at
`v<mastodon_version_requirement>` from the gemspec. It:

1. rewrites the host `Gemfile` to load this checkout
   (`script/ci/use_local_gem_in_host.rb`) and runs `bundle install`;
2. runs `bin/rails newsmast_mastodon:install`;
3. runs `db:prepare`, which also runs the gem's migrations after loading the
   host schema (`NewsmastMastodon::SchemaLoadMigrations`);
4. runs `bundle exec rspec` from the gem with `MASTODON_ROOT` set, so specs
   that call `require_host!` run instead of being skipped.

To test against another host, such as a Patchwork deployment branch, run the
`CI` workflow manually and set `host_mastodon_repo` and `host_mastodon_ref`.

### Running host mode locally

```bash
git clone --depth 1 --branch v4.6.5 https://github.com/mastodon/mastodon.git ../mastodon-host
ruby script/ci/use_local_gem_in_host.rb ../mastodon-host .
cd ../mastodon-host
bundle install
RAILS_ENV=test bin/rails newsmast_mastodon:install
RAILS_ENV=test bin/rails db:prepare
cd ../newsmast-mastodon
BUNDLE_GEMFILE=../mastodon-host/Gemfile MASTODON_ROOT=../mastodon-host RAILS_ENV=test bundle exec rspec
```
