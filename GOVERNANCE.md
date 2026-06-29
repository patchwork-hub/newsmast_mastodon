# Governance

This document defines how project decisions are made and how changes are merged.

## Roles

- Maintainers: listed in `MAINTAINERS.md`; responsible for review and release decisions.
- Contributors: anyone who submits issues, pull requests, or documentation updates.

## Decision making

- Routine fixes and documentation updates: maintainer merge after CI passes.
- Behavioral changes or new dependencies: require maintainer review and tests.
- Breaking changes: must be announced in `CHANGELOG.md` under `Unreleased` with
  migration notes in the pull request.

## Pull request policy

1. CI must pass.
2. Changelog policy must pass for behavior/code changes.
3. At least one maintainer review is required for non-trivial changes.
4. Security-sensitive changes should include threat/risk notes in the PR body.

## Release policy

- Release tags use `v<version>` and must match `lib/newsmast_mastodon/version.rb`.
- Release automation publishes to RubyGems from tagged commits.
- Release notes are tracked in `CHANGELOG.md`.

## Communication

- Support routing: `SUPPORT.md`
- Security reporting: `SECURITY.md`
- Conduct reporting: `CODE_OF_CONDUCT.md`

## Related documents

- Maintainer ownership: `MAINTAINERS.md`
- Contribution workflow: `CONTRIBUTING.md`
- Release notes and change policy: `CHANGELOG.md`
