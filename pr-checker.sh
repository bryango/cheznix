#!/bin/bash
# check pr status

set -e

REPO=NixOS/nixpkgs
BASE_URL=https://github.com
REPO_URL="$BASE_URL/$REPO"

prNumber=$1
trackedBranch=$2

[[ -n $trackedBranch ]] || trackedBranch="nixpkgs-unstable"
(
  targetHash=$(gh api "/repos/$REPO/commits/$trackedBranch" --jq .sha)
  [[ "$trackedBranch" != "$targetHash" ]] && >&2 echo "# $trackedBranch: $REPO_URL/commit/$targetHash"
) &

if [[ -z $prNumber ]]; then
  cmd="gh --repo \"$REPO\" pr list --author \"@me\" --state merged --limit 10"
  >&2 echo "# re-run and specify a PR to check, e.g."
  >&2 echo "$ $cmd"
  eval "$cmd"
  exit
fi

if commitHash=$(gh --repo "$REPO" pr view --json mergeCommit --jq .mergeCommit.oid "$prNumber");
then :; else
  commitHash=$prNumber # allow using plain hash
fi
compareLink="$REPO/compare/$commitHash...$trackedBranch"

>&2 echo "# checking $prNumber: $BASE_URL/$compareLink"

gh api "repos/$compareLink?per_page=1000000&page=100" --jq .status

wait # for the background process
