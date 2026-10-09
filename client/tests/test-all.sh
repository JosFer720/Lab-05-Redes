#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
failed=0

run_suite() {
  local name=$1 script=$2
  printf '\n===== %s =====\n' "${name}"
  if "${SCRIPT_DIR}/${script}"; then
    printf '[PASS] Suite %s\n' "${name}"
  else
    printf '[FAIL] Suite %s\n' "${name}" >&2
    failed=1
  fi
}

run_suite DNS test-dns.sh
run_suite LDAP test-ldap.sh
run_suite WEB test-web.sh
run_suite MAIL test-mail.sh
run_suite FTP test-ftp.sh

printf '\n===== Resultado integrado =====\n'
if (( failed == 0 )); then
  echo '[PASS] Todos los servicios respondieron correctamente.'
else
  echo '[FAIL] Una o más suites fallaron.' >&2
fi
exit "${failed}"
