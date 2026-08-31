# workmux project configs for the sdp monorepo

These are **reference copies**. The live files must sit inside the repo:

```
~/workspaces/sdp/.workmux.yaml
~/workspaces/sdp/s-analytics/sources/.workmux.yaml
```

They are deliberately kept out of the repo's git (added to
`.git/info/exclude`, not `.gitignore`) because they impose a personal tool
choice on the whole team. That means git does not back them up — hence these
copies.

Restore with:

```sh
cp ~/dotfiles/workmux/project-configs/sdp/.workmux.yaml ~/workspaces/sdp/
cp ~/dotfiles/workmux/project-configs/sdp/s-analytics/sources/.workmux.yaml \
   ~/workspaces/sdp/s-analytics/sources/
printf '%s\n' .workmux.yaml s-analytics/sources/.workmux.yaml \
  >> ~/workspaces/sdp/.git/info/exclude
```

Both delegate dependency setup to worktrunk (`wt hook pre-start`) rather than
reimplementing it. See `~/dotfiles/bin/README.md` for why.
