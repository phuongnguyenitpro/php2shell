#!/usr/bin/env bash
# PHP2Shell Community: read-only local inventory (not an exploit/compromise detector).
set -Eeuo pipefail
LC_ALL=C
ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/php-version.sh
source "$ROOT/lib/php-version.sh"

echo "PHP2SHELL CHECK | $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "READ ONLY. Does not scan web endpoints or verify absence of compromise."
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  printf 'Operating system: %s\n' "$PRETTY_NAME"
fi
if command -v dpkg-query >/dev/null 2>&1; then
  echo "Package manager: dpkg/APT (vendor backports require separate verification)"
elif command -v rpm >/dev/null 2>&1; then
  echo "Package manager: RPM (manual vendor advisory verification required)"
else
  echo "Package manager: unknown (manual verification required)"
fi
echo
echo "Installed PHP executables (CLI != web runtime):"
found=0
for branch in 8.1 8.2 8.3 8.4 8.5; do
  for base in php php-fpm php-cgi; do
    binary="$base$branch"
    if ! command -v "$binary" >/dev/null 2>&1; then continue; fi
    found=1
    line="$("$binary" -v 2>/dev/null | head -n 1 || true)"
    version="$(php2shell_get_version "$line" || true)"
    if [[ -z "$version" ]]; then
      printf '  %-16s UNKNOWN (must inspect)\n' "$binary"
      continue
    fi
    case "$(php2shell_version_status "$version")" in
      PATCHED_UPSTREAM_BASELINE) status="UPSTREAM BASELINE MET; verify vendor package and live SAPI";;
      BELOW_UPSTREAM_BASELINE) status="POTENTIALLY AFFECTED; check vendor backport";;
      EOL_UPSTREAM_VENDOR_CHECK) status="EOL upstream; migrate or verify maintained vendor backport";;
      *) status="UNKNOWN; manual inspection";;
    esac
    printf '  %-16s %-12s %s\n' "$binary" "$version" "$status"
  done
done
if (( ! found )); then echo "  No common binaries found: inspect containers/custom runtime."; fi

echo
echo "Installed PHP packages (metadata only):"
if command -v dpkg-query >/dev/null 2>&1; then
  dpkg-query -W -f='${binary:Package}\t${Version}\n' 'php*' 2>/dev/null || true
elif command -v rpm >/dev/null 2>&1; then
  rpm -qa | grep -E '^(php|rh-php|ea-php)' || true
fi
echo
echo "PHP-FPM service units:"
if command -v systemctl >/dev/null 2>&1; then
  systemctl list-unit-files --no-pager --type=service 'php*-fpm.service' 2>/dev/null || true
fi
echo
echo "Detected FPM pool configs (names only; settings shown selectively):"
for branch in 8.1 8.2 8.3 8.4 8.5; do
  dir="/etc/php/$branch/fpm/pool.d"
  [[ -d "$dir" ]] || continue
  while IFS= read -r -d '' pool; do
    printf '  %s\n' "$pool"
    grep -Ei '^[[:space:]]*(php_admin_value|php_value)\[(memory_limit|post_max_size|upload_max_filesize|session[.]upload_progress[.]enabled|fatal_error_backtraces)\]' "$pool" 2>/dev/null || true
  done < <(find "$dir" -maxdepth 1 -type f -name '*.conf' -print0)
done
echo
echo "LIMITATIONS: does not check real Nginx/Apache vhost-to-pool mapping, vendor"
echo "backports, custom containers, request-effective settings or past exploitation."
echo "A runtime below upstream baseline is not proof that its vendor package is unpatched."
echo "Sources: https://www.php.net/ ; https://www.php2shell.com/#upgrade-php"
