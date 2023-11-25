## Bisect `staging` regressions

**Reference:** https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md#staging

PRs merged into the `staging` branch are not immediately built by hydra.
They are manually batched and merged into `staging-next` for a mass hydra rebuild.
Therefore a commit in the middle of a staging branch may _not_ enjoy any useful binary cache, at that time in the commit history.
To find a cached build we must go all the way to the branching point (either in its future or in its past).

As an example, let us consider https://github.com/NixOS/nixpkgs/pull/246963.
We would like to undo the commits.
However, it is merged into `staging`, so its parent may not (and indeed does not) have binary cache and will take forever to build!
To find a cached build:

### back to the future from its ancestors

We check its ancestors successively, for a commit that belongs to some PR which has been merged into `master`, not `staging`.
[This commit](https://github.com/NixOS/nixpkgs/commit/3e483a0e1fc75a57e2ef551c416f52ec598a426d) is an automatic sync from the hydra built `staging-next` to `staging`. At some time in its future, it is manually merged back into `staging-next` and finally back into `master` (https://github.com/NixOS/nixpkgs/pull/248496). This is the branch point which lies in the _future_ of the PR https://github.com/NixOS/nixpkgs/pull/246963 of our interest.

In order to get rid of https://github.com/NixOS/nixpkgs/pull/246963 which comes from `staging`, we can simply go to the parent (https://github.com/NixOS/nixpkgs/pull/249953) of the branch point (https://github.com/NixOS/nixpkgs/pull/248496). The price is that we also lose everything else that comes along the `staging` merge. To get a list of `staging-next` merges, go to:

https://github.com/NixOS/nixpkgs/pulls?q=head%3Astaging-next+sort%3Acreated-desc

### straight to the future along its descendants

This is not possible from the GitHub webui, but once we have a local checkout of nixpkgs, we can do:
```bash
rev=92e83bfab5d0dac17ed868fd1ba2118193597f42  ## pr #246963
git log --reverse --ancestry-path --topo-order "$rev"^..master
```
scroll down towards the future and look for the next `staging-next` merge. This is the branch point #248496 as above.
