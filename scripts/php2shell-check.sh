#!/usr/bin/env bash
# PHP2Shell Community: local read-only PHP inventory, including multiple versions.
# Not a remote scanner, exploit test, proof of patching or compromise detector.
set -Eeuo pipefail
LC_ALL=C
ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/php-version.sh
source "$ROOT/lib/php-version.sh"

echo "PHP2SHELL CHECK | $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "READ ONLY. Detects common PHP binaries; does not verify web-facing SAPI or compromise."
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  printf 'Operating system: %s\n' "${PRETTY_NAME:-unknown}"
fi
if command -v dpkg-query >/dev/null 2>&1; then
  echo "Package manager: dpkg/APT (vendor backports need separate verification)"
elif command -v rpm >/dev/null 2>&1; then
  echo "Package manager: RPM (manual vendor advisory verification required)"
else
  echo "Package manager: unknown (manual verification required)"
fi

echo
echo "Detected PHP executables (CLI != web-serving runtime):"
declare -A seen=()
found=0
shopt -s nullglob
for candidate in php php-fpm php-cgi \
  /usr/bin/php[0-9]* /usr/bin/php-cgi[0-9]* /usr/sbin/php-fpm[0-9]* \
  /usr/local/bin/php[0-9]* /usr/local/bin/php-cgi[0-9]* \
  /usr/local/sbin/php-fpm[0-9]*; do
  bin="$candidate"
  if [[ "$bin" != */* ]]; then
    command -v "$bin" >/dev/null 2>&1 || continue
    bin="$(command -v "$bin")"
  fi
  [[ -f "$bin" && -x "$bin" ]] || continue
  real="$(readlink -f "$bin" 2>/dev/null || printf '%s' "$bin")"
  [[ -z "${seen[$real]+x}" ]] || continue
  seen["$real"]=1
  found=1
  line="$("$bin" -v 2>/dev/null | head -n 1 || true)"
  version="$(php2shell_get_version "$line" || true)"
  if [[ -z "$version" ]]; then
    printf '  %-35s UNKNOWN (inspect manually)\n' "$bin"
    continue
  fi
  case "$(php2shell_version_status "$version")" in
    PATCHED_UPSTREAM_BASELINE) status="UPSTREAM BASELINE MET; verify vendor and live SAPI";;
    BELOW_UPSTREAM_BASELINE) status="POTENTIALLY AFFECTED; check vendor backport";;
    EOL_UPSTREAM_VENDOR_CHECK) status="EOL upstream; migrate or verify maintained vendor support";;
    *) status="UNKNOWN BRANCH/BUILD; manual review";;
  esac
  printf '  %-35s %-12s %s\n' "$bin" "$version" "$status"
done
if (( ! found )); then
  echo "  No PHP binaries in standard locations/PATH; inspect containers and custom builds."
fi

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
echo "Detected standard FPM pool configs (names and selected settings):"
for dir in /etc/php/*/fpm/pool.d; do
  [[ -d "$dir" ]] || continue
  while IFS= read -r -d '' pool; do
    printf '  %s\n' "$pool"
    grep -Ei '^[[:space:]]*(php_admin_value|php_value)\[(memory_limit|post_max_size|upload_max_filesize|session[.]upload_progress[.]enabled|fatal_error_backtraces)\]' "$pool" 2>/dev/null || true
  done < <(find "$dir" -maxdepth 1 -type f -name '*.conf' -print0)
done

echo
echo "LIMITATIONS: This report does not map a virtual host to its active FPM pool,"
echo "verify backported CVE fixes, inspect all containers/custom paths or detect prior compromise."
echo "Always check package advisory, actual web-serving PHP SAPI and old worker processes."
echo "Sources: https://www.php.net/ ; https://www.php2shell.com/#upgrade-php"
