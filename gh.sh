#!/usr/bin/env bash
# gh.sh — Ghostty config sync helper (repo-local)
#
# Commands:
#   push     Copy local Ghostty config into repo, commit, and FORCE push
#   pull     Pull repo and update local Ghostty config (backup made)
#   diff     Show differences between repo and local
#   install  Symlink repo config into Ghostty config path
#   reload   Best-effort reload/restart of Ghostty
#
# Usage:
#   ./gh.sh push|pull|diff|install|reload
#
# Env overrides:
#   REPO_GHOSTTY_PATH    (default: ghostty/config inside this repo)
#   GIT_REMOTE           (default: origin)
#   GIT_BRANCH           (default: main)
#   GHOSTTY_CONFIG_PATH  (override auto-detected Ghostty config path)

set -eo pipefail

# Safe defaults
: "${REPO_GHOSTTY_PATH:=ghostty/config}"
: "${GIT_REMOTE:=origin}"
: "${GIT_BRANCH:=main}"

say()  { printf "\033[1;32m%s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$*" >&2; }
die()  { printf "\033[1;31mError:\033[0m %s\n" "$*" >&2; exit 1; }
timestamp() { date +"%Y%m%d-%H%M%S"; }

detect_platform_config_path() {
  # Returns absolute path to Ghostty "config" file
  local path
  case "$(uname -s)" in
    Darwin) path="$HOME/Library/Application Support/com.mitchellh.ghostty/config" ;;
    Linux)  path="$HOME/.config/ghostty/config" ;;
    *)      die "Unsupported OS. Set GHOSTTY_CONFIG_PATH env var." ;;
  esac
  if [ -n "${GHOSTTY_CONFIG_PATH:-}" ]; then
    path="$GHOSTTY_CONFIG_PATH"
  fi
  printf "%s" "$path"
}

repo_abs_path() {
  # Path (relative to repo root) for config within the repo
  mkdir -p "$(dirname "$REPO_GHOSTTY_PATH")"
  printf "%s" "$REPO_GHOSTTY_PATH"
}

copy_to_repo() {
  local local_conf="$1"
  local repo_target
  repo_target="$(repo_abs_path)"
  mkdir -p "$(dirname "$repo_target")"
  cp -f "$local_conf" "$repo_target"
}

copy_to_local() {
  local local_conf="$1"
  local repo_target backup
  repo_target="$(repo_abs_path)"

  [ -e "$repo_target" ] || die "No repo config at $repo_target"

  if [ -e "$local_conf" ]; then
    backup="${local_conf}.bak-$(timestamp)"
    say "Backing up local config to: $backup"
    cp -f "$local_conf" "$backup"
  else
    mkdir -p "$(dirname "$local_conf")"
  fi
  cp -f "$repo_target" "$local_conf"
}

do_push() {
  local conf repo_target
  conf="$(detect_platform_config_path)"
  [ -e "$conf" ] || die "Ghostty config not found at: $conf"

  say "Copying Ghostty config → repo"
  copy_to_repo "$conf"

  repo_target="$(repo_abs_path)"

  # Force-add in case .gitignore would skip it
  say "Staging: $repo_target"
  git add -f "$repo_target" || die "git add failed"

  # Show what’s staged (for clarity)
  if ! git diff --cached --quiet; then
    say "Changes staged:"
    git diff --cached --name-status

    local msg="ghostty: update $(timestamp)"
    git commit -m "$msg" || true

    say "Force pushing to $GIT_REMOTE/$GIT_BRANCH…"
    git push --force "$GIT_REMOTE" "HEAD:$GIT_BRANCH"
    say "Force push complete ✅"
  else
    warn "No changes to commit."
  fi
}

do_pull() {
  say "Fetching latest from $GIT_REMOTE/$GIT_BRANCH…"
  git fetch "$GIT_REMOTE" "$GIT_BRANCH"

  # Ensure we are on the branch locally and tracking remote
  if git rev-parse --verify "$GIT_BRANCH" >/dev/null 2>&1; then
    git checkout "$GIT_BRANCH"
  else
    git checkout -B "$GIT_BRANCH" "$GIT_REMOTE/$GIT_BRANCH"
  fi

  git pull --ff-only "$GIT_REMOTE" "$GIT_BRANCH" || die "Failed to pull latest changes."

  local conf
  conf="$(detect_platform_config_path)"
  say "Updating local Ghostty config at: $conf"
  copy_to_local "$conf"
  say "Pull complete ✅"
}

do_diff() {
  local conf repo_target
  conf="$(detect_platform_config_path)"
  repo_target="$(repo_abs_path)"
  if [ -e "$repo_target" ] && [ -e "$conf" ]; then
    diff -u "$repo_target" "$conf" || true
  else
    warn "Missing file(s): repo($repo_target exists: $( [ -e "$repo_target" ] && echo yes || echo no )), local($conf exists: $( [ -e "$conf" ] && echo yes || echo no ))"
  fi
}

do_install_symlink() {
  local conf repo_target
  conf="$(detect_platform_config_path)"
  repo_target="$(repo_abs_path)"
  [ -e "$repo_target" ] || die "No repo config found at $repo_target"

  # Backup any existing file/symlink
  if [ -e "$conf" ] || [ -L "$conf" ]; then
    local backup="${conf}.bak-$(timestamp)"
    say "Backing up existing config to: $backup"
    mv "$conf" "$backup"
  else
    mkdir -p "$(dirname "$conf")"
  fi

  ln -s "$(pwd)/$repo_target" "$conf"
  say "Symlinked $conf → $(pwd)/$repo_target ✅"
}

reload_ghostty() {
  # Best-effort reload. Ghostty typically reads config at startup.
  case "$(uname -s)" in
    Darwin)
      if command -v osascript >/dev/null 2>&1; then
        say "Attempting to restart Ghostty (macOS)…"
        osascript -e 'tell application id "com.mitchellh.ghostty" to try
          quit
        end try' >/dev/null 2>&1 || true
        sleep 0.7
        osascript -e 'tell application id "com.mitchellh.ghostty" to activate' >/dev/null 2>&1 || true
        say "Relaunched Ghostty ✅"
      else
        warn "osascript not available; please restart Ghostty manually."
      fi
      ;;
    Linux)
      if command -v pgrep >/dev/null 2>&1 && pgrep -x ghostty >/dev/null 2>&1; then
        say "Sending SIGHUP to ghostty (Linux)…"
        pkill -HUP -x ghostty || true
        sleep 0.5
        if pgrep -x ghostty >/dev/null 2>&1; then
          warn "If changes didn’t apply, restart Ghostty manually (quit & reopen)."
        else
          say "Ghostty reloaded (or exited) ✅"
        fi
      else
        say "Ghostty not running; starting if available…"
        if command -v ghostty >/dev/null 2>&1; then
          nohup ghostty >/dev/null 2>&1 & disown || true
          say "Ghostty started ✅"
        else
          warn "Could not start ghostty; ensure it’s in PATH."
        fi
      fi
      ;;
    *)
      warn "Unsupported OS for automatic reload—please restart Ghostty manually."
      ;;
  esac
}

usage() {
  cat <<EOF
Usage: ./gh.sh [push|pull|diff|install|reload]

Commands:
  push     Copy local Ghostty config into repo, commit, and force push
  pull     Pull repo and install config locally (backup made)
  diff     Show differences between repo and local config
  install  Symlink repo config into Ghostty config path
  reload   Best-effort reload/restart of Ghostty

Defaults:
  REPO_GHOSTTY_PATH = $REPO_GHOSTTY_PATH
  GIT_REMOTE        = $GIT_REMOTE
  GIT_BRANCH        = $GIT_BRANCH

Notes:
- macOS config:  ~/Library/Application Support/com.mitchellh.ghostty/config
- Linux config:  ~/.config/ghostty/config
- Force push overwrites remote history for the branch above.
EOF
}

main() {
  case "${1:-}" in
    push) do_push ;;
    pull) do_pull ;;
    diff) do_diff ;;
    install) do_install_symlink ;;
    reload) reload_ghostty ;;
    *) usage; exit 1 ;;
  esac
}
main "$@"
