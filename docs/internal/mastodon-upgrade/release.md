# Gem Release Runbook

This is the living team runbook for releasing `newsmast_mastodon` to RubyGems.

Primary release mode in this repository:
- Tag-triggered CI publish via GitHub Actions.
- Trigger pattern: tags that match `v*`.

## 1. Prerequisites

1. You have push access to the repository.
2. RubyGems trusted publishing is configured for this repository.
3. Your local branch is up to date with `main`.
4. Working tree is clean before starting the release.
5. Commit and tag signing are configured for your Git identity.

Check:

```bash
git checkout main
git pull --ff-only origin main
git status
```

## 2. Versioning Policy (Compatibility-First)

Use compatibility-first versioning: `X.Y.Z.N`.

1. `X.Y.Z` tracks the target Mastodon version.
2. `N` is the gem patch level for that exact Mastodon line.
3. New Mastodon target -> reset to `.0` (for example `4.5.11.2` -> `4.5.12.0`).

Examples:

1. `4.5.11.0` -> `4.5.11.1` for gem-only fixes.
2. `4.5.11.1` -> `4.5.12.0` for next Mastodon compatibility line.

## 3. Files You Must Update

1. `lib/newsmast_mastodon/version.rb`
2. `CHANGELOG.md`

Do not manually edit version in `newsmast_mastodon.gemspec`; it reads from `NewsmastMastodon::VERSION`.

## 4. Preflight Checks

Run all checks before creating a release tag.

```bash
bundle install
bundle exec rspec
bundle exec rubocop
bundle exec rake build
```

Optional API checks (if release touches API behavior):

```bash
bundle exec rake api:verify
bundle exec rake api:postman
bundle exec rake api:smoke
```

## 5. Release Procedure (Tag-Triggered CI)

Replace `X.Y.Z.N` with the target gem version.

1. Update version constant.

```bash
# edit file and set VERSION = "X.Y.Z.N"
$EDITOR lib/newsmast_mastodon/version.rb
```

2. Update changelog.

Update `CHANGELOG.md` by:
- Moving release-ready entries from `Unreleased` into `## [X.Y.Z.N] - YYYY-MM-DD`.
- Creating a new empty `Unreleased` section at the top for future changes.

3. Re-run preflight checks.

```bash
bundle exec rspec
bundle exec rubocop
bundle exec rake build
```

4. Commit release changes.

```bash
git add lib/newsmast_mastodon/version.rb CHANGELOG.md
git commit -S -m "chore(release): vX.Y.Z.N"
git push origin main
```

5. Create and push the release tag.

```bash
git tag -s vX.Y.Z.N -m "Release vX.Y.Z.N"
git push origin vX.Y.Z.N
```

If signing is not yet configured in your environment, set it up before release.

6. Monitor GitHub Actions publish run.

```bash
gh run list --workflow "Publish to RubyGems" --limit 5
gh run watch
```

Web UI fallback:
- Open Actions and check workflow `Publish to RubyGems` for tag `vX.Y.Z.N`.

## 6. Post-Release Verification

1. Confirm gem version is visible on RubyGems.
2. Verify install succeeds.

```bash
gem search newsmast_mastodon --remote
gem install newsmast_mastodon --version X.Y.Z.N
```

3. Confirm source tag exists on remote.

```bash
git ls-remote --tags origin | grep "refs/tags/vX.Y.Z.N$"
```

## 7. Rollback And Incident Playbooks

### A) Publish failed before gem was released

1. Inspect workflow logs and fix the root cause.
2. If tag is bad, delete and recreate tag after the fix.

```bash
git tag -d vX.Y.Z.N
git push origin :refs/tags/vX.Y.Z.N
```

Then repeat release tagging.

### B) Gem published but must be withdrawn

1. Yank the gem version from RubyGems.
2. Remove the bad tag.
3. Prepare a fixed version and release a new version.

```bash
gem yank newsmast_mastodon -v X.Y.Z.N
git tag -d vX.Y.Z.N
git push origin :refs/tags/vX.Y.Z.N
```

Note: yanked gems remain in index history; always publish a corrected follow-up version.

## 8. Troubleshooting

1. Workflow did not trigger:
- Ensure tag matches `v*` (for example `v4.5.12.0`).
- Ensure tag exists on remote: `git ls-remote --tags origin`.

2. RubyGems authentication error:
- Verify trusted publishing is configured on RubyGems for this repository.
- Confirm workflow has `permissions.id-token: write`.

3. Version mismatch during build:
- Confirm `lib/newsmast_mastodon/version.rb` has the intended version.
- Confirm tag and version match exactly (`vX.Y.Z.N` vs `X.Y.Z.N`).

## 9. Operator Checklist

Use this checklist for each release:

1. Branch updated and clean working tree.
2. Version bump in `lib/newsmast_mastodon/version.rb`.
3. Changelog updated in `CHANGELOG.md`.
4. Tests/lint/build pass.
5. Release commit merged to `main`.
6. Tag `vX.Y.Z.N` created and pushed.
7. Release commit and tag are signed.
8. Publish workflow passed.
9. RubyGems version verified.
