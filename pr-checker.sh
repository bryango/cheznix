#!/bin/bash
# check pr status

set -e

prNumber=$1
trackedBranch=$2

[[ -n $trackedBranch ]] || trackedBranch="nixpkgs-unstable"

if [[ -z $prNumber ]]; then
  cmd='gh --repo NixOS/nixpkgs pr list --author "@me" --state merged --limit 10'
  >&2 echo "# re-run and specify a PR to check, e.g."
  >&2 echo "$ $cmd"
  eval "$cmd"
  exit
fi

if commitHash=$(gh --repo NixOS/nixpkgs pr view --json mergeCommit --jq .mergeCommit.oid "$prNumber");
then :; else
  commitHash=$prNumber # allow using plain hash
fi
compareLink="NixOS/nixpkgs/compare/$commitHash...$trackedBranch"

>&2 echo "# checking PR $prNumber: https://github.com/$compareLink"

gh api "repos/$compareLink?per_page=1000000&page=100" --jq .status
