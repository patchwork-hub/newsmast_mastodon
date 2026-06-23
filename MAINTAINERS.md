# Maintainers

This file documents repository ownership and review responsibilities.

## Active maintainers

| Name | Role | Contact |
| --- | --- | --- |
| Aung Kyaw Phyo | Lead maintainer | akp@binarylab.io |

## Responsibilities

- Maintainers review pull requests and decide release timing.
- Breaking changes require explicit changelog notes and migration guidance.
- Security reports are triaged through the process in `SECURITY.md`.

## Review and merge expectations

- CI must pass before merge.
- At least one maintainer review is required for non-trivial changes.
- Release tags should match `lib/newsmast_mastodon/version.rb`.

## Succession

If the lead maintainer becomes unavailable, patchwork-hub organization admins
may appoint replacement maintainers and update this file.

## Related documents

- Project governance and merge policy: `GOVERNANCE.md`
- Contribution workflow: `CONTRIBUTING.md`
- Support routing: `SUPPORT.md`
- Security reporting: `SECURITY.md`
