#!/usr/bin/env nix
#! nix env shell nixpkgs#bash nixpkgs#gh --command bash
# shellcheck shell=bash
# check pr status

set -eo pipefail

REPO=NixOS/nixpkgs
BASE_URL=https://github.com
REPO_URL="$BASE_URL/$REPO"

prNumber=$1
trackedBranch=$2

[[ -n $trackedBranch ]] || trackedBranch="nixpkgs-unstable"
(
  targetHash=$(gh api "/repos/$REPO/commits/$trackedBranch" --jq .sha)
  [[ "$trackedBranch" != "$targetHash" ]] && >&2 echo "# $trackedBranch: $REPO_URL/commit/$targetHash"
  [[ -z "$prNumber" ]] && echo "$targetHash"
) &

if [[ -z $prNumber ]]; then
  cmd="gh --repo \"$REPO\" pr list --author \"@me\" --state merged --limit 10"
  >&2 echo "# re-run and specify a PR to check, e.g."
  >&2 echo "$ $cmd"
  eval "$cmd >&2"
  wait
  exit
fi

if commitHash=$(gh --repo "$REPO" pr view --json mergeCommit --jq .mergeCommit.oid "$prNumber"); then
  if [[ -z $commitHash ]]; then
    >&2 echo "# PR #$prNumber is not yet merged; see: $REPO_URL/pull/$prNumber"
    exit 1
  fi
else
  commitHash=$prNumber # allow using plain hash
fi
compareLink="$REPO/compare/$commitHash...$trackedBranch"

>&2 echo "# checking $prNumber: $BASE_URL/$compareLink"

gh api "repos/$compareLink?per_page=1000000&page=100" --jq .status

wait # for the background process
