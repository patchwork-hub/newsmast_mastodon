# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

## [4.5.11] - 2026-06-15

### Fixed

- Resolved single-gem sync regressions in the consolidated engine.
- Fixed API V1 behavior across account, channel, timeline, settings, webhook,
    notification token, drafted status, and local-only post endpoints.
- Aligned search indexing and support layers (Chewy indexes, authentication/user
    preparation concerns, helper behavior, and spec/dummy routing harnesses).
