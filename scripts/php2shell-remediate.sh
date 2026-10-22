#!/usr/bin/env bash
# PHP2Shell Community interactive remediation helper (Ubuntu/Debian PHP-FPM only).
# Default: inspect first; changes require explicit typed confirmation.
set -Eeuo pipefail
LC_ALL=C
ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/php-version.sh
source "$ROOT/lib/php-version.sh"
BACKUP_ROOT="/var/backups/php2shell-community"
declare -a branches=()
branch=""
min_fix=""
pool=""
fpm_bin=""
manager=""

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*"; }
require_root() { (( EUID == 0 )) || die "Use sudo for changes. Audit does not require root."; }
confirm() {
  local expected="$1" response
  read -r -p "Type $expected to continue: " response || return 1
  [[ "$response" == "$expected" ]]
}
version_target() {
  case "$1" in
    8.2) printf '8.2.35';;
    8.3) printf '8.3.36';;
    8.4) printf '8.4.27';;
    8.5) printf '8.5.12';;
    *) return 1;;
  esac
}
os_ok() {
  [[ -r /etc/os-release ]] || return 1
  . /etc/os-release
  [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]
}
discover() {
  branches=()
  for b in 8.2 8.3 8.4 8.5; do
    if command -v "php-fpm$b" >/dev/null 2>&1 &&
       command -v dpkg-query >/dev/null 2>&1 &&
       dpkg-query -W -f='${Status}' "php$b-fpm" 2>/dev/null | grep -q 'install ok installed'; then
      branches+=("$b")
    fi
  done
}
choose_branch() {
  discover
  (( ${#branches[@]} > 0 )) || { note "No supported Debian/Ubuntu packaged PHP-FPM branches found."; return 1; }
  echo "PHP-FPM branches installed:"
  local i n
  for i in "${!branches[@]}"; do
    printf ' %d) PHP %s -> patch baseline %s\n' "$(( i + 1 ))" "${branches[i]}" "$(version_target "${branches[i]}")"
  done
  read -r -p "Select number: " n || return 1
  [[ "$n" =~ ^[0-9]+$ ]] || return 1
  (( n >= 1 && n <= ${#branches[@]} )) || return 1
  branch="${branches[n-1]}"
  min_fix="$(version_target "$branch")"
  fpm_bin="$(command -v "php-fpm$branch")"
  printf 'Selected PHP %s, minimum fixed upstream %s\n' "$branch" "$min_fix"
}
candidate_meets_upstream() {
  local ver="$1" upstream=""
  if [[ "$ver" =~ (8[.]2[.][0-9]+|8[.]3[.][0-9]+|8[.]4[.][0-9]+|8[.]5[.][0-9]+) ]]; then
    upstream="${BASH_REMATCH[1]}"
  fi
  [[ -n "$upstream" ]] || return 1
  [[ "$(php2shell_version_status "$upstream")" == "PATCHED_UPSTREAM_BASELINE" ]]
}
inventory() {
  bash "$ROOT/php2shell-check.sh"
}
upgrade() {
  os_ok || die "Automatic upgrades are supported only on Ubuntu/Debian with APT."
  command -v apt-get >/dev/null 2>&1 || die "APT is unavailable."
  choose_branch || return
  require_root
  echo "This performs package changes and may require a PHP-FPM restart."
  confirm "REFRESH" || { note "Cancelled."; return; }
  apt-get update || die "apt-get update failed"
  local candidate current binary pkg
  candidate="$(apt-cache policy "php$branch-fpm" | awk '/Candidate:/ {print $2; exit}')"
  current="$(dpkg-query -W -f='${Version}' "php$branch-fpm" 2>/dev/null || true)"
  printf 'Installed: %s\nCandidate: %s\nUpstream target: %s\n' "$current" "$candidate" "$min_fix"
  if [[ -z "$candidate" || "$candidate" == "(none)" ]]; then
    note "No package candidate; aborting. Check repository/vendor."
    return
  fi
  if ! candidate_meets_upstream "$candidate"; then
    note "Candidate does not prove upstream fixed baseline."
    note "Vendor backports MAY be safe, but need matching CVE advisory and changelog."
    note "No unattended change made. Escalate for vendor/package verification."
    return
  fi
  local -a packages=()
  while IFS=$'\t' read -r pkg installed; do
    if [[ "$pkg" =~ ^php$branch(-[a-zA-Z0-9.+-]+)?$ && "$installed" != "" ]]; then
      packages+=("$pkg")
    fi
  done < <(dpkg-query -W -f='${binary:Package}\t${Version}\n' "php$branch*" 2>/dev/null || true)
  (( ${#packages[@]} > 0 )) || { note "No matching packages; aborted."; return; }
  echo "APT simulation; review dependency and removal actions carefully:"
  apt-get -s install --only-upgrade "${packages[@]}" || die "APT simulation failed"
  echo "Review above. If removal/downgrade/branch change appears, CANCEL."
  confirm "UPGRADE-$branch" || { note "Cancelled; no packages upgraded."; return; }
  # Explicit block against package removals during this one-purpose security change.
  apt-get -y --no-remove install --only-upgrade "${packages[@]}" || die "Package update failed"
  echo "APT completed. Restart PHP-FPM only after approval (brief downtime possible)."
  if confirm "RESTART-$branch"; then
    systemctl restart "php$branch-fpm" || die "Restart failed; follow incident/change procedure."
    systemctl is-active --quiet "php$branch-fpm" || die "PHP-FPM not active after restart."
  else
    note "WARNING: workers not restarted; remediation NOT complete."
  fi
  "$fpm_bin" -v | head -n 1 || true
  note "Next: verify the live vhost/pool, package advisory, old workers and application smoke tests."
}
choose_pool() {
  local dir="/etc/php/$branch/fpm/pool.d" p n i
  local -a pools=()
  [[ -d "$dir" ]] || { note "No standard pool.d path."; return 1; }
  while IFS= read -r -d '' p; do pools+=("$p"); done < <(find "$dir" -maxdepth 1 -type f -name '*.conf' -print0 | sort -z)
  (( ${#pools[@]} > 0 )) || { note "No regular pool config files."; return 1; }
  echo "Select ONE PHP-FPM pool file (repeat for other pools):"
  for i in "${!pools[@]}"; do printf ' %d) %s\n' "$((i+1))" "${pools[i]}"; done
  read -r -p "Pool number: " n || return 1
  [[ "$n" =~ ^[0-9]+$ ]] || return 1
  (( n >= 1 && n <= ${#pools[@]} )) || return 1
  pool="${pools[n-1]}"
  [[ -f "$pool" && ! -L "$pool" ]] || die "Symlink/non-file pool refused."
  # Appending at EOF is safe only when a file declares exactly one pool section.
  local sections
  sections="$(grep -Ec '^[[:space:]]*\[[^]]+\]' "$pool" || true)"
  [[ "$sections" == "1" ]] || die "File has $sections sections. Manual pool review required."
  [[ -w "$pool" ]] || die "Pool config not writable."
}
mitigate() {
  os_ok || die "Automated FPM mitigation supports only Debian/Ubuntu layouts."
  choose_branch || return
  require_root
  choose_pool || return
  echo
  echo "TEMPORARY MITIGATION ONLY - NOT A PHP2SHELL PATCH."
  echo "Disables session upload progress; lowers POST/upload limit;"
  echo "disables fatal error backtraces on PHP 8.5."
  echo "These may break upload features. Test in DEV/UAT first."
  local post upload memory_option="" upload_choice
  echo " 1) No application uploads: post_max_size=8M, upload_max_filesize=6M"
  echo " 2) Applications accept uploads: post_max_size=32M, upload_max_filesize=28M"
  read -r -p "Choose request-size profile [1/2]: " upload_choice || return
  case "$upload_choice" in
    1) post="8M"; upload="6M";;
    2) post="32M"; upload="28M";;
    *) note "Cancelled."; return;;
  esac
  echo
  echo "OOM mitigation memory_limit=-1 may exhaust host RAM."
  echo "It requires independently verified container/cgroup isolation and resource"
  echo "bounds. No cgroup/worker-isolation validation is automated."
  if confirm "I-VERIFIED-ISOLATION"; then
    memory_option="php_admin_value[memory_limit] = -1"
  else
    note "Skipping memory_limit=-1 (other partial mitigations can still be applied)."
  fi
  local stamp backup temp cleaned sections
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  backup="$BACKUP_ROOT/$stamp/php$branch/$(basename "$pool")"
  mkdir -p "$(dirname "$backup")"
  cp -a -- "$pool" "$backup" || die "Backup failed"
  temp="$(mktemp "$(dirname "$pool")/.php2shell.XXXXXX")"
  # Only remove the previously managed block; do not rewrite other admin settings.
  sed '/^; BEGIN PHP2SHELL COMMUNITY MANAGED$/,/^; END PHP2SHELL COMMUNITY MANAGED$/d' "$pool" > "$temp"
  {
    echo
    echo "; BEGIN PHP2SHELL COMMUNITY MANAGED"
    echo "; Temporary exposure reduction. Does NOT fix both CVEs."
    echo "php_admin_value[session.upload_progress.enabled] = 0"
    echo "php_admin_value[post_max_size] = $post"
    echo "php_admin_value[upload_max_filesize] = $upload"
    if [[ "$branch" == "8.5" ]]; then
      echo "php_admin_value[fatal_error_backtraces] = 0"
    fi
    if [[ -n "$memory_option" ]]; then echo "$memory_option"; fi
    echo "; END PHP2SHELL COMMUNITY MANAGED"
  } >> "$temp"
  chmod --reference="$pool" "$temp"
  chown --reference="$pool" "$temp"
  echo "Change preview (managed block only):"
  sed -n '/^; BEGIN PHP2SHELL COMMUNITY MANAGED$/,/^; END PHP2SHELL COMMUNITY MANAGED$/p' "$temp"
  echo "Backup: $backup"
  confirm "APPLY-MITIGATION-$branch" || { rm -f -- "$temp"; note "Cancelled."; return; }
  cp -a -- "$temp" "$pool" && rm -f -- "$temp" || die "Cannot install config"
  if ! "$fpm_bin" -t >/dev/null 2>&1; then
    cp -a -- "$backup" "$pool"
    die "php-fpm config validation failed: original file restored. No restart."
  fi
  note "Config syntax OK. Restart is REQUIRED to apply pre-request settings."
  if ! confirm "RESTART-$branch"; then
    note "WARNING: config written but NOT effective until PHP-FPM workers restart."
    return
  fi
  if ! systemctl restart "php$branch-fpm" || ! systemctl is-active --quiet "php$branch-fpm"; then
    cp -a -- "$backup" "$pool" || true
    systemctl restart "php$branch-fpm" || true
    die "Restart failed, original pool file restored; verify service urgently."
  fi
  note "Restart OK; verify live pool settings and functionality; temporary mitigation is incomplete."
  note "Rollback pool file: cp -a '$backup' '$pool' && php-fpm$branch -t && systemctl restart php$branch-fpm"
}
echo "PHP2Shell Community Remediation Menu"
echo "Risk: patch now. Config mitigation is NOT a complete fix."
while :; do
  echo
  echo " 1) Check OS and installed PHP versions (read-only)"
  echo " 2) Upgrade CURRENT PHP branch using official APT candidate (confirm twice)"
  echo " 3) Apply TEMPORARY PHP-FPM pool mitigation (backup/confirm/restart)"
  echo " 0) Exit"
  read -r -p "Choose [0-3]: " answer || exit 0
  case "$answer" in
    1) inventory;;
    2) upgrade;;
    3) mitigate;;
    0) exit 0;;
    *) echo "Invalid choice.";;
  esac
done
