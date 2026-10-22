#!/usr/bin/env bash
# Read-only local inventory. No external scanning, package changes or restart.
set -Eeuo pipefail
BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$BASE_DIR/lib/php-version.sh"
printf 'PHP2SHELL COMMUNITY AUDIT | %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
printf 'Mode: READ-ONLY | No external scanning\n'
if [[ -r /etc/os-release ]]; then . /etc/os-release; printf 'OS: %s\n' "${PRETTY_NAME:-unknown}"; fi
printf '\n== PHP binaries ==\n'
declare -A seen=()
shopt -s nullglob
for bin in php php-cgi php-fpm /usr/bin/php[0-9]* /usr/bin/php-cgi[0-9]* /usr/sbin/php-fpm[0-9]* /usr/local/bin/php /usr/local/sbin/php-fpm; do
  if [[ "$bin" != */* ]]; then command -v "$bin" >/dev/null 2>&1 || continue; bin="$(command -v "$bin")"; fi
  [[ -x "$bin" ]] || continue
  real="$(readlink -f "$bin" 2>/dev/null || printf '%s' "$bin")"
  [[ -z "${seen[$real]+x}" ]] || continue; seen[$real]=1
  line="$("$bin" -v 2>/dev/null | head -n 1 || true)"
  if version="$(php2shell_get_version "$line")"; then printf '%s\t%s\t%s\n' "$bin" "$version" "$(php2shell_version_status "$version")"; else printf '%s\tUNKNOWN\n' "$bin"; fi
done
printf '\n== PHP packages ==\n'
if command -v dpkg-query >/dev/null 2>&1; then dpkg-query -W -f='${binary:Package}\t${Version}\n' 'php*' 2>/dev/null || true; elif command -v rpm >/dev/null 2>&1; then rpm -qa | grep -E '^(php|rh-php|ea-php)' || true; fi
printf '\n== PHP-FPM units ==\n'
if command -v systemctl >/dev/null 2>&1; then systemctl list-unit-files --type=service --no-legend 'php*-fpm.service' 2>/dev/null || true; fi
printf '\nCheck live SAPI, containers and vendor backports manually. CLI is not proof of remediation.\n'
