# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses compatibility-first versioning (`X.Y.Z.N`, where `X.Y.Z`
tracks the target Mastodon version and `N` is the gem patch level).

## [Unreleased]

### Added

- Added `SUPPORT.md` with support routing and response expectations.
- Added `MAINTAINERS.md` to document ownership and review responsibilities.
- Added `GOVERNANCE.md` with decision, merge, and release policy.
- Added `config/data/README.md` with starter-pack data provenance guidance.
- Added per-directory provenance records under `config/data/*/PROVENANCE.md`.
- Added `NOTICE` with license and dependency attribution guidance.

### Changed

- Updated `CODE_OF_CONDUCT.md` enforcement contact details.
- Expanded `CONTRIBUTING.md` with versioning, breaking-change, and release guidance.
- Aligned `CONTRIBUTING.md` release checklist with checksum and provenance attestation workflow steps.
- Added community/governance/support links to `README.md`.
- Linked non-security conduct reporting path from `SECURITY.md`.
- Hardened release workflow with checksum generation and build provenance attestation.
- Cross-linked governance, maintainer, and support documents for easier navigation.
- Refactored CI workflows to use a shared runtime setup action, added per-job timeouts, and introduced `ci-ok` as a stable aggregate required check.
- Added `no-changelog` PR label bypass support to `changelog-policy` for approved non-behavioral changes.
- Dropped end-of-life Ruby 3.1 and 3.2 from CI; the pipeline now tests only stable Ruby versions (3.3 and 3.4), and `required_ruby_version` was raised to `>= 3.3.0`. Documented the Ruby requirement in `README.md`, `CONTRIBUTING.md`, and `docs/ci/jobs.md`.
- Expanded security automation with `bundler-audit` and workflow linting (`actionlint` + `zizmor`) and tightened dependency-review severity gating.
- Hardened release gating with a protected `rubygems` environment and verification that release tags are ancestors of `main`.
- Updated branch/tag ruleset definitions to require the new checks, enforce linear history, protect `v*` tags, and skip Copilot review on draft PRs.
- Grouped Dependabot major updates for Bundler and GitHub Actions to reduce update noise.

## [4.5.11] - 2026-06-15

### Fixed

- Resolved single-gem sync regressions in the consolidated engine.
- Fixed API V1 behavior across account, channel, timeline, settings, webhook,
    notification token, drafted status, and local-only post endpoints.
- Aligned search indexing and support layers (Chewy indexes, authentication/user
    preparation concerns, helper behavior, and spec/dummy routing harnesses).
