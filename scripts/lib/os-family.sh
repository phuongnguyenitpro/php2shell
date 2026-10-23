#!/usr/bin/env bash
# Source-only helpers. Host remediation MUST read /etc/os-release directly.
php2shell_os_detect() {
  local file="${1:-/etc/os-release}" id="" like="" ver=""
  [[ -r "$file" ]] || { printf 'unknown|unknown|unknown|none|audit\n'; return; }
  local ID= ID_LIKE= VERSION_ID= NAME=
  # OS vendor-provided key/value format.
  . "$file"
  id="${ID,,}"; like=" ${ID_LIKE,,} "; ver="${VERSION_ID:-unknown}"
  local family=unknown pm=none tier=audit
  case "$id" in
    debian|ubuntu) family=debian; pm=apt; tier=remediate ;;
    rhel|rocky|almalinux|centos|ol) family=rhel; pm=dnf; tier=remediate ;;
    fedora|amzn) family=rhel; pm=dnf ;;
    alpine) family=alpine; pm=apk ;;
    sles|sled|opensuse*|suse) family=suse; pm=zypper ;;
    arch|manjaro) family=arch; pm=pacman ;;
    *)
      case "$like" in
        *" debian "*) family=debian; pm=apt ;;
        *" rhel "*|*" fedora "*) family=rhel; pm=dnf ;;
        *" suse "*) family=suse; pm=zypper ;;
        *" arch "*) family=arch; pm=pacman ;;
      esac
      ;;
  esac
  # CentOS Linux is EOL; Stream 8 is EOL as well. Allow Stream 9 only.
  if [[ "$id" == centos && ( "$NAME" != *"CentOS Stream"* || "$ver" != 9* ) ]]; then tier=audit; fi
  # EOL/ESM Ubuntu or Debian builds need manual vendor checks.
  if [[ "$family" == debian && "$tier" == remediate ]]; then
    case "$id:$ver" in
      ubuntu:22.04|ubuntu:24.04|ubuntu:26.04|debian:12|debian:13) ;;
      *) tier=audit ;;
    esac
  fi
  # DNF5/RHEL 10 and unknown/legacy versions require a separate supported adapter.
  if [[ "$family" == rhel && "$tier" == remediate && "$ver" != 8* && "$ver" != 9* ]]; then tier=audit; fi
  printf '%s|%s|%s|%s|%s\n' "$id" "$ver" "$family" "$pm" "$tier"
}
