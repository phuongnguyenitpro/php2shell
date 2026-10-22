#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/lib/php-version.sh"
for pair in "8.2.35 PATCHED_UPSTREAM_BASELINE" "8.3.36 PATCHED_UPSTREAM_BASELINE" "8.4.27 PATCHED_UPSTREAM_BASELINE" "8.5.12 PATCHED_UPSTREAM_BASELINE" "8.3.27 BELOW_UPSTREAM_BASELINE"; do
  read -r v expect <<< "$pair"
  got="$(php2shell_version_status "$v")"
  [[ "$got" == "$expect" ]] || { echo "FAIL $v expected $expect got $got"; exit 1; }
  echo "PASS $v $got"
done
bash -n "$ROOT/scripts/php2shell-check.sh"
bash -n "$ROOT/scripts/php2shell-remediate.sh"
echo "PASS script syntax"
