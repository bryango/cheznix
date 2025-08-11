# Bisect `staging` regressions

- **Reference:** https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md#staging
- **`staging-next`** https://github.com/NixOS/nixpkgs/pulls?q=head%3Astaging-next+sort%3Acreated-desc

PRs merged into the `staging` branch are not immediately built by hydra.
They are manually batched and merged into `staging-next` for a mass hydra rebuild.
Therefore a commit in the middle of a staging branch may _not_ enjoy any useful binary cache, at that time in the commit history.
To find a cached build we must go all the way to the branching point (either in its future or in its past).

As an example, let us consider:
- _The suspect:_ https://github.com/NixOS/nixpkgs/pull/246963

We would like to undo this commit.
However, it is merged into `staging`, so its parent may not (and indeed does not) have binary cache and will take forever to build!
To find a cached build:

## To the merge point along its descendants

This is not possible from the GitHub webui, but once we have a local checkout of nixpkgs, we can do:
```bash
rev=92e83bfab5d0dac17ed868fd1ba2118193597f42  ## pr NixOS/nixpkgs#246963
git log --reverse --ancestry-path --topo-order "$rev"^..master
```
The `--ancestry-path` flag focuses onto the commits that connects `"$rev"^` to master
and discard irrelevant branches.
We then scroll down towards the future and look for the next `staging > staging-next > master` merge.
This is:
- _The `staging-next` merge:_  https://github.com/NixOS/nixpkgs/pull/248496

In order to undo the suspect https://github.com/NixOS/nixpkgs/pull/246963 which comes from `staging`,
we can simply go to the parent https://github.com/NixOS/nixpkgs/pull/249953
of the `staging-next` merge https://github.com/NixOS/nixpkgs/pull/248496.
The price is that we also lose everything else that comes along the `staging` merge. 


## Back to the future from its ancestors

The same can be achieved with the Github webui, although it might be a bit convoluted.
In particular, `git log --reverse "$rev"^..master` can be achieved with a Github `/compare`,
but there is no way to specify `--ancestry-path --topo-order` so there might be some disordered or irrelevant commits.

Alternatively, we can go the other way around by checking the _ancestors_ of the suspect, successively.
We are trying to find a commit that belongs to some PR which has been merged into `master`, not `staging`.
We find that:
- _The ancestor:_ https://github.com/NixOS/nixpkgs/commit/3e483a0e1fc75a57e2ef551c416f52ec598a426d

is an automatic sync from the hydra built `staging-next` to `staging`. At some time in its future, it is manually merged back into `staging-next` and finally back into `master`, through https://github.com/NixOS/nixpkgs/pull/248496. We've hence successfully located the `staging-next` merge as above.
Note that this merge point lies in the _future_ of the suspect https://github.com/NixOS/nixpkgs/pull/246963 of our interest, but it can be located by going to the _past_ of our suspect.

# a more general prescription

- with `git bisect` we can get a list of good and bad revs
- just `git bisect skip` if the commit is not cached, to avoid rebuilding the universe
- the suspects are given by `git log bad_revs ^good_revs`
- `good_rev..bad_rev` is just a shorthand for `bad_rev ^good_rev`; in general, it is actually easier to use the latter syntax to specify multiple good revs and bad revs
- it is possible that `--ancestry-path good_rev..bad_revs` gives an empty set; that simply means that these two revs are on the tips of two branches and their merge base is given by `git merge-base`
- one can generally narrow it down to 200 or so commits, and we can assess the relevance of these suspects by hand

This is how we discover https://github.com/NixOS/nixpkgs/issues/431934.
