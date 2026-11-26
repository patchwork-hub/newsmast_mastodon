#!/usr/bin/env bash
# Point a host Mastodon bundle at a local newsmast_mastodon checkout.
#
# The host Gemfile pins newsmast_mastodon to a git source with a branch, so a
# plain `bundle install` in the host would load the gem from that branch
# rather than from the code under test. A Bundler local git override swaps in
# the checkout without editing the host Gemfile.
#
# Usage:
#   script/ci/use_local_gem_in_host.sh configure <host_dir> <gem_dir>
#     Run before `bundle install` in the host.
#   script/ci/use_local_gem_in_host.sh verify <host_dir> <gem_dir>
#     Run after `bundle install`; fails unless the host resolves the gem
#     from <gem_dir>.
set -euo pipefail

mode="${1:?usage: $0 configure|verify <host_dir> <gem_dir>}"
host_dir="$(cd "${2:?host_dir required}" && pwd -P)"
gem_dir="$(cd "${3:?gem_dir required}" && pwd -P)"

cd "$host_dir"

case "$mode" in
  configure)
    if ! grep -Eq "^[[:space:]]*gem[[:space:]]+['\"]newsmast_mastodon['\"]" Gemfile; then
      echo "::error::${host_dir}/Gemfile does not declare newsmast_mastodon"
      exit 1
    fi

    # Local overrides only apply to git sources that pin a :branch. Read that
    # branch from the host Gemfile through Bundler's own DSL.
    pinned_branch="$(ruby -rbundler -e '
      dep = Bundler::Dsl.evaluate("Gemfile", nil, {}).dependencies.find { |d| d.name == "newsmast_mastodon" }
      src = dep&.source
      abort "newsmast_mastodon is not a git source in the host Gemfile (got #{src.class})" unless src.is_a?(Bundler::Source::Git)
      abort "newsmast_mastodon git source in the host Gemfile has no :branch" if src.branch.to_s.empty?
      print src.branch
    ')"

    # Even with the branch check disabled, Bundler resolves the pinned branch
    # name inside the local checkout (`git rev-parse --verify <branch>`). A PR,
    # tag or detached-SHA checkout has no such ref, so point one at HEAD.
    current_branch="$(git -C "$gem_dir" symbolic-ref --quiet --short HEAD || true)"
    if [ "$current_branch" != "$pinned_branch" ]; then
      git -C "$gem_dir" branch --force "$pinned_branch" HEAD
    fi

    bundle config set --local "local.newsmast_mastodon" "$gem_dir"
    # The checked-out branch (if any) won't match the branch pinned in the
    # host Gemfile, and the locked revision may not exist in a shallow
    # checkout.
    bundle config set --local disable_local_branch_check true
    bundle config set --local disable_local_revision_check true
    # The override rewrites the locked revision, so the lockfile must be
    # writable.
    bundle config set --local frozen false
    bundle config set --local deployment false

    echo "Host bundle will load newsmast_mastodon from ${gem_dir} (host Gemfile pins branch '${pinned_branch}')"
    ;;

  verify)
    resolved="$(bundle info newsmast_mastodon --path)"
    resolved="$(cd "$resolved" && pwd -P)"
    echo "newsmast_mastodon resolved from: ${resolved}"
    bundle info newsmast_mastodon

    if [ "$resolved" != "$gem_dir" ]; then
      echo "::error::host bundle resolved newsmast_mastodon from ${resolved}, expected ${gem_dir}"
      exit 1
    fi
    ;;

  *)
    echo "::error::unknown mode '${mode}' (expected configure or verify)"
    exit 2
    ;;
esac
