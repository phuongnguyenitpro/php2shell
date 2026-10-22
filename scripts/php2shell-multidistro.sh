#!/usr/bin/env bash
# PHP2Shell v2 multi-distribution dispatcher. Never remote scans or exploits.
set -Eeuo pipefail
export LC_ALL=C
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/lib/os-family.sh"
mode="${1:-check}"
if [[ "$mode" == -h || "$mode" == --help ]]; then
  cat <<'HELP'
Usage: bash scripts/php2shell-multidistro.sh {check|audit|verify|plan|remediate}
check/audit/verify/plan: read-only (DNF/APT may read/update cache during package queries)
remediate: interactive, Debian APT helper or gated RHEL-family DNF4 update
OS-specific inventory is informational; it is not CVE-remediation proof.
HELP
  exit 0
fi
[[ $# -le 1 ]] || { echo 'Unexpected arguments' >&2; exit 64; }
case "$mode" in check|audit|verify|plan|remediate) ;; *) echo 'Unknown action' >&2; exit 64;; esac
IFS='|' read -r distro os_version family manager tier < <(php2shell_os_detect /etc/os-release)
header() {
  printf 'PHP2Shell v2 | action=%s | OS=%s %s | family=%s | PM=%s | remediation=%s\n' \
    "$mode" "$distro" "$os_version" "$family" "$manager" "$tier"
}
packages() {
  case "$manager" in
    apt) command -v dpkg-query >/dev/null && dpkg-query -W -f='${binary:Package}\t${Version}\n' 'php*' 2>/dev/null || true ;;
    dnf) command -v rpm >/dev/null && rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\n' 2>/dev/null | grep -Ei '^(php|rh-php|ea-php)' || true ;;
    apk) command -v apk >/dev/null && apk info -v 2>/dev/null | grep -E '^php[0-9]' || true ;;
    zypper) command -v rpm >/dev/null && rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\n' 2>/dev/null | grep -Ei '^(php|php[0-9])' || true ;;
    pacman) command -v pacman >/dev/null && pacman -Q 2>/dev/null | grep -E '^php([ -]|$)' || true ;;
    *) echo 'No package adapter; review runtime manually' ;;
  esac
}
services() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl list-unit-files --type=service --no-pager --no-legend 2>/dev/null | grep -Ei '(^|[[:space:]])(php.*fpm|rh-php.*fpm|ea-php.*fpm)' || true
  elif command -v rc-service >/dev/null 2>&1; then
    rc-service -l 2>/dev/null | grep -Ei '^php.*fpm|^php-fpm' || true
  fi
}
paths() {
  local f
  for f in /etc/php/*/fpm/pool.d/*.conf /etc/php-fpm.d/*.conf \
           /etc/opt/remi/php*/php-fpm.d/*.conf /etc/php*/php-fpm.d/*.conf \
           /etc/php*/php-fpm.conf /etc/php-fpm.conf; do
    [[ -f "$f" ]] && printf '  %s\n' "$f"
  done
}
repo_warnings() {
  printf '\nVhost mapping not proven: inspect Nginx fastcgi_pass / Apache handlers / containers.\n'
  printf 'CHECK: vendor advisories/backports, installed extensions, old FPM workers, EOL and IR logs.\n'
}
read_only() {
  header
  printf '\n-- PHP packages --\n'; packages
  printf '\n-- PHP-FPM services --\n'; services
  printf '\n-- Standard FPM configuration paths --\n'; paths
  printf '\n-- Upstream PHP version inventory --\n'
  case "$mode" in
    audit) bash "$ROOT/php2shell-audit.sh" ;;
    verify) bash "$ROOT/php2shell-verify.sh" ;;
    *) bash "$ROOT/php2shell-check.sh" ;;
  esac
  repo_warnings
}
plan() {
  header
  echo 'READ ONLY PATCH PLAN (NOT proof of a fixed CVE).'
  packages
  case "$manager" in
    apt)
      if command -v apt-cache >/dev/null 2>&1; then
        echo 'Installed PHP-FPM package candidates:'
        local p
        while read -r p; do [[ -z "$p" ]] || apt-cache policy "$p"; done < <(dpkg-query -W -f='${binary:Package}\n' 'php*-fpm' 2>/dev/null || true)
      fi
      ;;
    dnf)
      if command -v dnf >/dev/null 2>&1; then
        echo 'Security advisories for each PHP2Shell CVE (vendor updateinfo may be absent):'
        dnf -q updateinfo info --cve CVE-2026-109618 2>&1 || true
        dnf -q updateinfo info --cve CVE-2026-109619 2>&1 || true
        echo 'Do not infer vulnerability status from empty advisory results.'
      fi
      ;;
    apk) echo 'Alpine (read-only): apk info -v; apk version -l "<" (requires current package index).' ;;
    zypper) echo 'SUSE (read-only): zypper lp; zypper list-updates; inspect vendor advisories.' ;;
    pacman) echo 'Arch (read-only): pacman -Q; vendor/advisory review needed.' ;;
    *) echo 'Unsupported package manager.' ;;
  esac
  repo_warnings
}
require_type() {
  local expected="$1" got
  read -r -p "Enter $expected to confirm: " got || return 1
  [[ "$got" == "$expected" ]]
}
rhel_guard() {
  [[ "$tier" == remediate && "$family" == rhel ]] || { echo 'Not a supported RHEL-family remediation target.' >&2; return 1; }
  [[ "$distro" == rhel || "$distro" == rocky || "$distro" == almalinux || "$distro" == centos || "$distro" == ol ]] || return 1
  [[ "$os_version" == 8* || "$os_version" == 9* ]] || { echo 'DNF5/new platform requires manual change review.' >&2; return 1; }
  command -v dnf >/dev/null && command -v rpm >/dev/null || { echo 'DNF/RPM not found.' >&2; return 1; }
  [[ $EUID -eq 0 ]] || { echo 'Requires root for package changes. Use sudo.' >&2; return 1; }
  # Prepackaged RPMs only. Avoid switching Remi parallel/SCL/EasyApache streams.
  if rpm -qa --qf '%{NAME}\n' | grep -Eq '^(php[0-9]+|rh-php|ea-php)'; then
    echo 'Parallel PHP streams detected (Remi/SCL/EasyApache). MANUAL ONLY.' >&2
    return 1
  fi
}
rhel_remediate() {
  rhel_guard || return 1
  local -a pkgs=() cves=(CVE-2026-109618 CVE-2026-109619)
  local audit="" cve
  mapfile -t pkgs < <(rpm -qa --qf '%{NAME}\n' | grep -E '^php($|-[[:alnum:]_.+-]+$)' | sort -u || true)
  (( ${#pkgs[@]} )) || { echo 'No standard PHP RPM packages; abort.'; return 1; }
  echo 'Installed PHP RPM packages:'; printf '  %s\n' "${pkgs[@]}"
  echo 'Verifying available vendor advisory evidence for PHP2Shell:'
  for cve in "${cves[@]}"; do
    audit="$(dnf -q updateinfo list --cve "$cve" 2>&1 || true)"
    printf '%s\n%s\n' "$cve" "$audit"
    if ! grep -Eiq '(^|[[:space:]])php(-|[[:space:]]|$)' <<< "$audit"; then
      echo "NO CONFIRMED PHP ADVISORY for $cve. No automated remediation allowed." >&2
      return 1
    fi
  done
  echo 'Read-only transaction preview for installed PHP RPMs (exit status may be nonzero due to --assumeno):'
  dnf --assumeno upgrade --cve "${cves[0]}" --cve "${cves[1]}" "${pkgs[@]}" || true
  echo 'STOP: review exact package transaction, repository origin and security advisory.'
  echo 'BACKUP: source/DB/uploads/configs/VM snapshot and rollback point required externally.'
  echo 'Will NOT change repos, module stream, remove packages, or restart FPM.'
  require_type 'BACKUP-VERIFIED' || { echo 'Cancelled.'; return 1; }
  require_type 'APPROVE-PHP-DNF' || { echo 'Cancelled.'; return 1; }
  local backup_dir conf
  install -d -m 0700 /var/backups/php2shell-v2 || return 1
  backup_dir="$(mktemp -d /var/backups/php2shell-v2/backup.XXXXXXXX)" || return 1
  chmod 0700 "$backup_dir"
  for conf in /etc/php.ini /etc/php-fpm.conf /etc/php-fpm.d; do
    [[ ! -e "$conf" ]] || cp -a -- "$conf" "$backup_dir/" || { echo 'Config backup failed. Aborting.' >&2; return 1; }
  done
  printf 'Configuration backup: %s\n' "$backup_dir"
  dnf upgrade --cve "${cves[0]}" --cve "${cves[1]}" "${pkgs[@]}"
  echo 'Patch transaction attempted. FPM NOT restarted. Verify advisory, web-serving runtime and test applications.'
}
if [[ "$mode" == remediate ]]; then
  header
  case "$tier:$family" in
    remediate:debian) exec bash "$ROOT/php2shell-remediate.sh" ;;
    remediate:rhel) rhel_remediate ;;
    *) echo 'AUDIT ONLY. Unsupported/EOL distro or unvalidated package source.' >&2; exit 3 ;;
  esac
elif [[ "$mode" == plan ]]; then plan
else read_only
fi
