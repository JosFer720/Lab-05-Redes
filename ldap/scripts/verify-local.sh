#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DN=${BASE_DN:-dc=aerolinea,dc=redes,dc=test}
LDAP_TEST_USER=${LDAP_TEST_USER:-}
LDAP_TEST_PASSWORD=${LDAP_TEST_PASSWORD:-}
failed=0

check() {
  local description=$1
  shift
  if "$@"; then printf '[PASS] %s\n' "${description}"; else printf '[FAIL] %s\n' "${description}" >&2; failed=1; fi
}

check 'servicio activo' systemctl is-active --quiet slapd
check 'servicio habilitado' systemctl is-enabled --quiet slapd
check 'puerto 389 escuchando' bash -c "ss -lnt | grep -Eq '[:.]389[[:space:]]'"
check 'unidad People disponible' ldapsearch -x -LLL -H ldap://127.0.0.1 -b "ou=People,${BASE_DN}" -s base dn
check 'usuarios disponibles' bash -c "ldapsearch -x -LLL -H ldap://127.0.0.1 -b 'ou=People,${BASE_DN}' -s one uid | grep -q '^uid:'"

if [[ -n ${LDAP_TEST_USER} && -n ${LDAP_TEST_PASSWORD} ]]; then
  check 'autenticación válida' ldapwhoami -x -H ldap://127.0.0.1 -D "uid=${LDAP_TEST_USER},ou=People,${BASE_DN}" -w "${LDAP_TEST_PASSWORD}"
fi
exit "${failed}"
