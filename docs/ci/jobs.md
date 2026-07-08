# CI Jobs

This repository uses multiple CI jobs for quality, compatibility, and security.

| Workflow | Job | Purpose | Requirements |
| --- | --- | --- | --- |
| `CI` | `changelog-policy` | Ensures PRs that touch code/workflows update `CHANGELOG.md`. | Pull request event; skipped when PR includes `no-changelog` label. |
| `CI` | `lint` | Runs RuboCop for style and static checks. | Ruby 3.3, 3.4 matrix. |
| `CI` | `api-contract` | Verifies route/controller/Postman docs sync via `bundle exec rake api:verify`. | No external services required. |
| `CI` | `test` | Runs main RSpec suite (sqlite mode by default) and uploads coverage artifacts. | Redis service; Ruby 3.3, 3.4 matrix. |
| `CI` | `test-postgres-subset` | Validates targeted model specs against real Postgres schema bootstrap. | Postgres + Redis services; Ruby 3.4. |
| `CI` | `compatibility` | Runs upgrade-safety and version-sync compatibility specs. | Ruby 3.4. |
| `CI` | `host-integration` | Optional host Mastodon integration checks and override drift validation. | Manual `workflow_dispatch` with host inputs. |
| `CI` | `host-integration-full` | Optional full host runtime integration checks with DB/Redis/ES. | Manual `workflow_dispatch` with host inputs. |
| `CI` | `ci-ok` | Aggregates required CI jobs into one stable merge gate. | Runs after required CI jobs complete. |
| `Security` | `dependency-review` | Detects risky dependency changes in pull requests. | Pull request event. |
| `Security` | `bundler-audit` | Scans resolved gem dependencies against RubySec advisories. | PR, push to main, and weekly schedule. |
| `Security` | `lint-workflows` | Lints workflow files using `actionlint` and `zizmor`. | PR, push to main, and weekly schedule. |
| `Security` | `codeql` | Runs scheduled and event-driven Ruby CodeQL static analysis. | `security-events: write` permission. |

## Running host integration jobs

Host integration jobs are manual-only and are triggered with `workflow_dispatch`
inputs in `ci.yml`.
