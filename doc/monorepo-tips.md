# Managing monorepos: nixpkgs developments made easy

## sync from upstream

This ensures minimal blob transfers in a sparse checkout:
```bash
# pin the latest hash from the nixpkgs-unstable channel
nix registry pin nixpkgs

# find the "$rev" hash by inspecting the cached registry
nix registry list

# fetch the git "$rev" from the remote
git fetch origin "$rev"

# bump local master to the "$rev"
git switch master
git reset --hard "$rev"

# sync github remote with upstream from the web interface,
# and then fetch the upstream "$rev"
git fetch origin master

# reset the remote master to the channel "$rev"
git push --force
```
