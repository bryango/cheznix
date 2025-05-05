# nixpkgs patches

Collect nixpkgs patches here. Generated with:

```bash
here="~/.config/home-manager/nixpkgs-config"
if branch=$(git rev-parse --abbrev-ref HEAD); then
  git format-patch origin/master --output="$here/$branch.patch"
fi
```

Files that ends with `.patch` will be loaded automatically.
