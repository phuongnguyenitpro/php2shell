#!/usr/bin/env bash
# Shared helpers. Works with upstream version numbers only.
php2shell_get_version() {
  local line="${1:-}"
  if [[ "$line" =~ PHP[[:space:]]+([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    return 1
  fi
}
php2shell_version_status() {
  local v="${1:-}" major minor patch baseline
  if [[ ! "$v" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then printf 'UNKNOWN_VERSION\n'; return; fi
  major="${BASH_REMATCH[1]}" minor="${BASH_REMATCH[2]}" patch="${BASH_REMATCH[3]}"
  if (( major != 8 )); then
    if (( major < 8 )); then printf 'EOL_UPSTREAM_VENDOR_CHECK\n'; else printf 'UNKNOWN_BRANCH\n'; fi
    return
  fi
  case "$minor" in
    2) baseline=35 ;;
    3) baseline=36 ;;
    4) baseline=27 ;;
    5) baseline=12 ;;
    0|1) printf 'EOL_UPSTREAM_VENDOR_CHECK\n'; return ;;
    *) printf 'UNKNOWN_BRANCH\n'; return ;;
  esac
  if (( 10#$patch >= baseline )); then printf 'PATCHED_UPSTREAM_BASELINE\n'; else printf 'BELOW_UPSTREAM_BASELINE\n'; fi
}
