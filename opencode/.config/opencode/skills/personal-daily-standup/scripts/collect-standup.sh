#!/usr/bin/env bash
# Collect the current stand-up window of local work.
# Window = yesterday 12:00 (lunch) -> now, because the stand-up covers everything
# said-and-done since the previous day's afternoon, not just today's commits.
# Usage: collect-standup.sh [since-expr] [until-expr]
#   since-expr: any `git log --since` value. Default: yesterday 12:00 local.
#   until-expr: any `git log --until` value. Default: none.
# Prints, per commit: date+time | subject, plus the project/tenant codes derived
# from the paths it touched. Then uncommitted work and unpushed branches.

set -uo pipefail

default_since() {
  # BSD (macOS) first, GNU fallback.
  date -v-1d '+%Y-%m-%d 12:00:00' 2>/dev/null \
    || date -d 'yesterday' '+%Y-%m-%d 12:00:00'
}

SINCE="${1:-$(default_since)}"
UNTIL="${2:-}"
EMAIL="$(git config user.email)"

until_args=()
[ -n "$UNTIL" ] && until_args=(--until="$UNTIL")

# Derive product/tenant codes from touched paths. Patterns are NOT anchored at the
# start of the line: git reports paths relative to the repo root, which may sit
# several levels above the tenant tree (e.g. s-analytics/sources/packages/tenant-x).
# Adjust the patterns if the repo's product boundary is not packages/tenant-* or
# config-tenants/*.
codes_from_paths() {
  sed -n -e 's#.*packages/tenant-\([a-z0-9-]*\)/.*#\1#p' \
         -e 's#.*config-tenants/\([a-z0-9-]*\)/.*#\1#p' \
    | sort -u | paste -sd, -
}

projects_for() {
  git show --pretty=format: --name-only "$1" | codes_from_paths
}

echo "=== COMMITS (author=$EMAIL, since=$SINCE${UNTIL:+, until=$UNTIL}) ==="
shas="$(git log --all --no-merges --since="$SINCE" "${until_args[@]}" \
  --author="$EMAIL" --pretty=format:'%H' | awk '!seen[$0]++')"

if [ -z "$shas" ]; then
  echo "(none)"
else
  while read -r sha; do
    [ -z "$sha" ] && continue
    meta="$(git show -s --pretty=format:'%ad | %s' --date=format:'%a %d.%m. %H:%M' "$sha")"
    projs="$(projects_for "$sha")"
    echo "${meta}"
    echo "    projects: ${projs:-<none / infra>}"
  done <<< "$shas"
fi

echo
echo "=== WORKING TREES (all, incl. worktrunk/spawned ones) ==="
# `git status` only ever sees the CURRENT worktree. With one worktree per task
# (worktrunk / spawn-feature-env), most in-progress work — the part that matters
# most at stand-up — lives outside it and would silently vanish from the report.
# Each dirty tree is annotated with the newest mtime among its changed files so
# stale trees (months-old scratch dirs) can be told apart from today's work.
here="$(git rev-parse --show-toplevel)"
newest_mtime() {
  local wt="$1" newest=0 m
  while read -r rel; do
    [ -z "$rel" ] && continue
    m="$(stat -f %m "$wt/$rel" 2>/dev/null || stat -c %Y "$wt/$rel" 2>/dev/null)" || continue
    [ -n "$m" ] && [ "$m" -gt "$newest" ] && newest="$m"
  done
  [ "$newest" = 0 ] && return 1
  date -r "$newest" '+%a %d.%m. %H:%M' 2>/dev/null || date -d "@$newest" '+%a %d.%m. %H:%M'
}

worktrees="$(git worktree list --porcelain | awk '/^worktree /{print $2}')"
dirty_any=0
while read -r wt; do
  [ -z "$wt" ] && continue
  [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ] && dirty_any=1
done <<< "$worktrees"
[ "$dirty_any" = 0 ] && echo "all worktrees clean"

while read -r wt; do
  [ -z "$wt" ] && continue
  st="$(git -C "$wt" status --porcelain 2>/dev/null)"
  [ -z "$st" ] && continue
  br="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  paths="$(printf '%s\n' "$st" | sed -e 's/^...//' -e 's/.* -> //')"
  when="$(printf '%s\n' "$paths" | newest_mtime "$wt" || echo '?')"
  mark=""; [ "$wt" = "$here" ] && mark=" (current)"
  echo "--- $wt$mark"
  echo "    branch: $br | last touched: $when"
  echo "    projects: $(printf '%s\n' "$paths" | codes_from_paths || true)"
  printf '%s\n' "$st" | sed 's/^/    /' | head -20
  cnt="$(printf '%s\n' "$st" | wc -l | tr -d ' ')"
  [ "$cnt" -gt 20 ] && echo "    ... (+$((cnt - 20)) more)"
done <<< "$worktrees"

echo
echo "=== BRANCH SYNC (local branches touched in window) ==="
git for-each-ref --format='%(refname:short) %(upstream:short) %(upstream:track)' refs/heads \
  | while read -r br up track; do
      # only report branches that carry commits from the window
      if git log --no-merges --since="$SINCE" "${until_args[@]}" --author="$EMAIL" \
           --pretty=format:'%H' "$br" 2>/dev/null | grep -q .; then
        if [ -z "${up:-}" ]; then
          echo "$br -> NO UPSTREAM (unpushed)"
        else
          echo "$br -> $up ${track:-[in sync]}"
        fi
      fi
    done
