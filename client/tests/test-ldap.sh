#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN=${DOMAIN:-aerolinea.redes.test}
BASE_DN=${BASE_DN:-dc=aerolinea,dc=redes,dc=test}
LDAP_HOST=${LDAP_HOST:-ldap.${DOMAIN}}
LDAP_PORT=${LDAP_PORT:-389}
LDAP_USER=${LDAP_USER:-}
LDAP_PASSWORD=${LDAP_PASSWORD:-}
failed=0

if [[ -z ${LDAP_USER} || -z ${LDAP_PASSWORD} ]]; then
  echo "Error: defina LDAP_USER y LDAP_PASSWORD." >&2
  exit 1
fi

check() {
  local id=$1 description=$2
  shift 2
  if "$@"; then printf '[PASS] %s %s\n' "${id}" "${description}"; else printf '[FAIL] %s %s\n' "${id}" "${description}" >&2; failed=1; fi
}
reject() {
  local id=$1 description=$2
  shift 2
  local output code
  if output=$("$@" 2>&1); then
    printf '[FAIL] %s %s\n' "${id}" "${description}" >&2
    failed=1
  else
    code=$?
    if [[ ${code} -eq 49 && ${output} == *'Invalid credentials (49)'* ]]; then
      printf '[PASS] %s %s\n' "${id}" "${description}"
    else
      printf '[FAIL] %s %s: %s\n' "${id}" "${description}" "${output}" >&2
      failed=1
    fi
  fi
}

LDAP_OPTIONS=(-x -o nettimeout=5 -H "ldap://${LDAP_HOST}:${LDAP_PORT}")
USER_DN="uid=${LDAP_USER},ou=People,${BASE_DN}"

query_users() {
  local output
  output=$(ldapsearch "${LDAP_OPTIONS[@]}" -LLL -b "ou=People,${BASE_DN}" -s one '(objectClass=inetOrgPerson)' uid) || return
  printf '%s\n' "${output}"
  grep -q '^uid: ' <<< "${output}"
}

query_attributes() {
  local output attribute
  output=$(ldapsearch "${LDAP_OPTIONS[@]}" -LLL -b "${USER_DN}" -s base uid cn sn mail) || return
  printf '%s\n' "${output}"
  for attribute in uid cn sn mail; do
    grep -q "^${attribute}: " <<< "${output}" || return 1
  done
}

check LDAP-01 'consulta de usuarios' query_users
check LDAP-02 'autenticación válida' ldapwhoami "${LDAP_OPTIONS[@]}" -D "${USER_DN}" -w "${LDAP_PASSWORD}"
reject LDAP-03 'autenticación inválida (LDAP 49)' ldapwhoami "${LDAP_OPTIONS[@]}" -D "${USER_DN}" -w incorrecta
check LDAP-04 'atributos requeridos: uid, cn, sn y mail' query_attributes
exit "${failed}"
