#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/os-family.sh"
fixture="$(mktemp)"; trap 'rm -f "$fixture"' EXIT
assert_os() {
  local id="$1" version="$2" like="$3" expected="$4" got
  printf 'ID=%q\nVERSION_ID=%q\nID_LIKE=%q\nNAME=%q\n' "$id" "$version" "$like" "${5:-$id}" > "$fixture"
  got="$(php2shell_os_detect "$fixture")"
  [[ "$got" == "$expected" ]] || { echo "FAIL $id $version expected $expected got $got" >&2; exit 1; }
  echo "PASS $id $version: $got"
}
assert_os ubuntu 24.04 debian 'ubuntu|24.04|debian|apt|remediate'
assert_os debian 12 '' 'debian|12|debian|apt|remediate'
assert_os debian 11 '' 'debian|11|debian|apt|audit'
assert_os ubuntu 20.04 debian 'ubuntu|20.04|debian|apt|audit'
assert_os ubuntu 26.04 debian 'ubuntu|26.04|debian|apt|remediate'
assert_os rocky 9.6 'rhel fedora' 'rocky|9.6|rhel|dnf|remediate'
assert_os almalinux 9.6 'rhel centos fedora' 'almalinux|9.6|rhel|dnf|remediate'
assert_os rhel 10.0 fedora 'rhel|10.0|rhel|dnf|audit'
assert_os ol 8.10 'rhel fedora' 'ol|8.10|rhel|dnf|remediate'
assert_os centos 7 core 'centos|7|rhel|dnf|audit'
assert_os centos 9 'rhel fedora' 'centos|9|rhel|dnf|remediate' 'CentOS Stream'
assert_os centos 8 'rhel fedora' 'centos|8|rhel|dnf|audit' 'CentOS Stream'
assert_os fedora 42 '' 'fedora|42|rhel|dnf|audit'
assert_os amzn 2023 fedora 'amzn|2023|rhel|dnf|audit'
assert_os alpine 3.22 '' 'alpine|3.22|alpine|apk|audit'
assert_os opensuse-leap 15.6 suse 'opensuse-leap|15.6|suse|zypper|audit'
assert_os arch rolling '' 'arch|rolling|arch|pacman|audit'
assert_os custom 1 'debian' 'custom|1|debian|apt|audit'
bash -n "$ROOT/scripts/lib/os-family.sh" "$ROOT/scripts/php2shell-multidistro.sh"
bash "$ROOT/scripts/php2shell-multidistro.sh" --help | grep -q 'Usage:'
if bash "$ROOT/scripts/php2shell-multidistro.sh" invalid >/dev/null 2>&1; then
  echo 'FAIL invalid action accepted' >&2; exit 1
fi
echo 'PASS syntax/help/invalid arguments'
