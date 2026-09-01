#!/usr/bin/env bash
# Shared bootstrap for the scheduled worklog jobs (worklog-standup, worklog-cycle).
#
# These run under launchd, which gives a job almost nothing: PATH is
# /usr/bin:/bin:/usr/sbin:/sbin, no shell rc files, no login environment. Every
# dependency therefore has to be established here explicitly.
#
# Source it, don't execute it.

set -euo pipefail

WL_HOME="${HOME:-/Users/$(id -un)}"
WL_OUT_ROOT="${WORKLOG_ROOT:-$WL_HOME/worklog}"
WL_LOG_DIR="$WL_OUT_ROOT/.log"
WL_REPO="${WORKLOG_REPO:-$WL_HOME/workspaces/sdp/s-analytics/sources}"
WL_SECRETS="${WORKLOG_SECRETS:-$WL_HOME/dotfiles/zsh/.zsh_secrets}"

# Homebrew first: opencode, node and jq all live there and none are on launchd's PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:$WL_HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

mkdir -p "$WL_LOG_DIR"

wl_log() {
	printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2
}

wl_die() {
	wl_log "ERROR: $*"
	wl_notify "worklog failed" "$*"
	exit 1
}

# macOS notification. Never fatal: a job that produced its file has done its
# work even if the notification centre refuses it.
wl_notify() {
	local title="$1" message="$2"
	osascript -e "display notification $(wl_osa_quote "$message") with title $(wl_osa_quote "$title")" >/dev/null 2>&1 || true
}

# AppleScript string literal: only \ and " need escaping.
wl_osa_quote() {
	printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
}

# Pull one `export NAME=...` line out of the secrets file.
#
# The file is not sourceable here: it allocates file descriptors with the
# `exec {var}<` form, which macOS's /bin/bash 3.2 cannot parse, and it reads
# from the login keychain, which a background agent should not be poking at.
# An already-exported value always wins, so an interactive run uses the real
# environment.
wl_load_secret() {
	local name="$1"
	[ -n "${!name:-}" ] && return 0
	[ -r "$WL_SECRETS" ] || return 1
	local line
	line=$(grep -E "^[[:space:]]*export[[:space:]]+$name=" "$WL_SECRETS" | tail -n 1) || return 1
	[ -n "$line" ] || return 1
	eval "$line"
	[ -n "${!name:-}" ]
}

# Keep a job's launchd log to the last few runs.
#
# StandardOutPath is append-only and never rotated, and a run logs its whole
# opencode transcript — tens of kilobytes a day, which buries the one line you
# actually want when something breaks. Truncate the existing inode rather than
# replacing the file: launchd holds an open descriptor on it, and a fresh inode
# would send every later line of this run into the unlinked old file.
wl_trim_log() {
	local file="$WL_LOG_DIR/$1.log" keep="${WORKLOG_LOG_LINES:-3000}"
	[ -f "$file" ] || return 0
	local lines
	lines=$(wc -l <"$file" | tr -d ' ')
	[ "$lines" -le "$keep" ] && return 0
	local tmp="$file.trim"
	tail -n "$keep" "$file" >"$tmp" 2>/dev/null || return 0
	cat "$tmp" >"$file"
	rm -f "$tmp"
}

# Only one instance of a given job at a time. A run can outlive its interval
# (a cold opencode start plus a large diff is minutes), and two agents writing
# the same output file would interleave.
wl_lock() {
	local name="$1"
	local dir="$WL_LOG_DIR/$name.lock"
	if ! mkdir "$dir" 2>/dev/null; then
		local pid
		pid=$(cat "$dir/pid" 2>/dev/null || echo "")
		if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
			wl_log "already running as pid $pid; skipping this run"
			exit 0
		fi
		wl_log "clearing stale lock from pid ${pid:-unknown}"
		rm -rf "$dir"
		mkdir "$dir" 2>/dev/null || wl_die "cannot acquire lock $dir"
	fi
	printf '%s\n' "$$" >"$dir/pid"
	# shellcheck disable=SC2064  # expand $dir now, the variable is gone at trap time
	trap "rm -rf '$dir'" EXIT
}

# Run a command with a wall-clock limit. macOS ships no timeout(1), and an
# opencode session that wedges on a permission prompt would otherwise hold the
# lock until the next reboot.
wl_run_limited() {
	local limit="$1"
	shift
	"$@" &
	local job=$!
	# The watchdog counts in one-second steps and holds no inherited stdio.
	# A single long `sleep` would be wrong twice over: killing the subshell
	# leaves the sleep orphaned, and that orphan keeps the caller's stdout open,
	# so anything reading this script's output blocks until the full limit
	# elapses even though the work finished in a minute.
	(
		waited=0
		while [ "$waited" -lt "$limit" ]; do
			kill -0 "$job" 2>/dev/null || exit 0
			sleep 1
			waited=$((waited + 1))
		done
		kill -TERM "$job" 2>/dev/null || true
		sleep 5
		kill -KILL "$job" 2>/dev/null || true
	) >/dev/null 2>&1 &
	local watchdog=$!
	local status=0
	wait "$job" || status=$?
	kill "$watchdog" 2>/dev/null || true
	wait "$watchdog" 2>/dev/null || true
	return "$status"
}

# Drive a headless opencode session and require it to have written a file.
#
# The output is taken from disk, never from stdout: the transcript carries
# banners, tool traces and reasoning, and parsing prose out of it is how these
# jobs silently start producing garbage.
#
# $1 output file (deleted first, so a stale file cannot pass as fresh)
# $2 prompt
# $3 extra opencode config as JSON, merged over the user's own
wl_opencode() {
	local out="$1" prompt="$2" config="$3"
	local model="${WORKLOG_MODEL:-anthropic/claude-sonnet-5}"
	local limit="${WORKLOG_TIMEOUT:-900}"

	mkdir -p "$(dirname "$out")"
	rm -f "$out"

	wl_log "opencode run (model=$model, dir=$WL_REPO, timeout=${limit}s)"
	local status=0
	OPENCODE_CONFIG_CONTENT="$config" wl_run_limited "$limit" \
		opencode run --dir "$WL_REPO" --model "$model" "$prompt" || status=$?

	if [ "$status" -ne 0 ]; then
		wl_log "opencode exited $status"
	fi
	[ -s "$out" ] || wl_die "opencode wrote nothing to $out (exit $status)"
	wl_log "wrote $out ($(wc -c <"$out" | tr -d ' ') bytes)"
}

# Config merged into every scheduled run. MCP servers are switched off by
# default: none of these jobs need one, several shell out to `npx -y` on a cold
# cache, and the Linear one wants a browser when its OAuth token lapses — all
# ways for an unattended run to hang or fail. Facts come from git and from the
# Linear REST call the job makes itself.
wl_config() {
	local allow_dir="$1"
	cat <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "autoupdate": false,
  "mcp": {
    "linear": { "enabled": false },
    "claude-design": { "enabled": false },
    "playwright": { "enabled": false },
    "prometheus": { "enabled": false },
    "perselio-docs": { "enabled": false }
  },
  "permission": {
    "external_directory": {
      "$allow_dir/**": "allow"
    }
  }
}
EOF
}
