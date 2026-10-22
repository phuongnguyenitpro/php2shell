#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/php-version.sh"
check() {
  local actual="$1" expected="$2" name="$3"
  if [[ "$actual" != "$expected" ]]; then printf 'FAIL %s: got %s, expected %s\n' "$name" "$actual" "$expected" >&2; exit 1; fi
  printf 'PASS %s\n' "$name"
}
check "$(php2shell_version_status 8.5.11)" BELOW_UPSTREAM_BASELINE '8.5 prepatch'
check "$(php2shell_version_status 8.5.12)" PATCHED_UPSTREAM_BASELINE '8.5 patched'
check "$(php2shell_version_status 8.4.26)" BELOW_UPSTREAM_BASELINE '8.4 prepatch'
check "$(php2shell_version_status 8.4.27)" PATCHED_UPSTREAM_BASELINE '8.4 patched'
check "$(php2shell_version_status 8.3.36)" PATCHED_UPSTREAM_BASELINE '8.3 patched'
check "$(php2shell_version_status 8.2.34)" BELOW_UPSTREAM_BASELINE '8.2 prepatch'
check "$(php2shell_version_status 8.2.35)" PATCHED_UPSTREAM_BASELINE '8.2 patched'
check "$(php2shell_version_status 8.1.33)" EOL_UPSTREAM_VENDOR_CHECK '8.1 EOL'
check "$(php2shell_version_status 7.4.33)" EOL_UPSTREAM_VENDOR_CHECK '7.4 EOL'
check "$(php2shell_version_status 8.6.0)" UNKNOWN_BRANCH '8.6 unknown'
check "$(php2shell_version_status garbage)" UNKNOWN_VERSION malformed
check "$(php2shell_get_version 'PHP 8.4.27 (fpm-fcgi)')" 8.4.27 'parse FPM'
check "$(php2shell_get_version 'PHP 8.5.12 (cli)')" 8.5.12 'parse CLI'
echo 'All baseline tests passed.'
