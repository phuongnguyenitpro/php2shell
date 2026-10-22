#!/usr/bin/env bash
# Upstream baseline check. Read-only; does NOT prove vendor CVE fixes or web-serving SAPI.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/php-version.sh"
upstream=0
case "${1:-}" in --upstream-only) upstream=1; shift;; --help|-h) echo 'Usage: php2shell-verify.sh [--upstream-only]'; exit 0;; esac
if (( $# )); then printf 'Unknown argument\n' >&2; exit 64; fi
pass=0 warn=0 fail=0 found=0
declare -A seen=()
shopt -s nullglob
for bin in php php-cgi php-fpm /usr/bin/php[0-9]* /usr/bin/php-cgi[0-9]* /usr/sbin/php-fpm[0-9]* /usr/local/bin/php /usr/local/sbin/php-fpm; do
  if [[ "$bin" != */* ]]; then command -v "$bin" >/dev/null 2>&1 || continue; bin="$(command -v "$bin")"; fi
  [[ -x "$bin" ]] || continue
  real="$(readlink -f "$bin" 2>/dev/null || printf '%s' "$bin")"
  [[ -z "${seen[$real]+x}" ]] || continue; seen[$real]=1; found=$((found+1))
  line="$("$bin" -v 2>/dev/null | head -n 1 || true)"
  if version="$(php2shell_get_version "$line")"; then
    status="$(php2shell_version_status "$version")"
    case "$status" in
      PATCHED_UPSTREAM_BASELINE) printf 'PASS %s %s\n' "$bin" "$version"; pass=$((pass+1));;
      BELOW_UPSTREAM_BASELINE|EOL_UPSTREAM_VENDOR_CHECK)
        if (( upstream )); then printf 'FAIL %s %s (upstream-only)\n' "$bin" "$version"; fail=$((fail+1)); else printf 'WARN %s %s (check vendor backport)\n' "$bin" "$version"; warn=$((warn+1)); fi;;
      *) printf 'WARN %s unknown branch/version\n' "$bin"; warn=$((warn+1));;
    esac
  else printf 'WARN %s unparseable version\n' "$bin"; warn=$((warn+1)); fi
done
if (( ! found )); then echo 'WARN No common PHP binary detected; inspect containers/embedded runtime'; warn=$((warn+1)); fi
printf 'Summary: %d PASS, %d WARN, %d FAIL\n' "$pass" "$warn" "$fail"
echo 'NOT CHECKED: actual web SAPI, vendor backport evidence, container, runtime restart or compromise'
if (( fail )); then exit 2; elif (( warn )); then exit 1; else exit 0; fi
