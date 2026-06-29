# Security Policy

## Reporting a vulnerability

If you believe you have found a security vulnerability in `newsmast_mastodon`,
please report it privately so we can investigate and ship a fix before the
issue is publicly disclosed.

- **Contact:** akp@binarylab.io
- **Do not** open a public GitHub issue, pull request, or discussion for
  security-sensitive reports.
- Include as much detail as possible: affected version, reproduction steps,
  proof-of-concept, and any suggested remediation.

For non-security conduct issues, use the reporting process in
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## Response SLA

- **Acknowledgement:** within **3 business days** of your report.
- **Triage & impact assessment:** within **10 business days**.
- **Fix or mitigation plan:** we aim to publish a patched release within
  **30 days** of confirmed reports, faster for critical severity issues.

We will keep you informed of progress and credit you in the release notes
unless you request otherwise.

## Scope

In scope:

- Code shipped in this gem (`app/`, `lib/`, `config/`, `db/migrate/`).
- Default configuration and initializers provided by this engine.

Out of scope:

- Vulnerabilities in Mastodon itself (report to the upstream project).
- Vulnerabilities in third-party dependencies (report to their maintainers;
  we will update our dependency when a fix is available).
- Issues requiring physical access, social engineering, or compromised
  developer machines.
- Denial-of-service via unrealistic request volumes against a self-hosted
  instance.

## Supported versions

We provide security fixes for the latest minor release on the `main` branch.
Older releases may receive backports at maintainers' discretion.
