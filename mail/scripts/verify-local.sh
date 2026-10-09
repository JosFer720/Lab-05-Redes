#!/usr/bin/env bash
set -Eeuo pipefail

MAIL_TEST_USER=${MAIL_TEST_USER:-}
MAIL_TEST_PASSWORD=${MAIL_TEST_PASSWORD:-}
failed=0

check() {
  local description=$1
  shift
  if "$@"; then printf '[PASS] %s\n' "${description}"; else printf '[FAIL] %s\n' "${description}" >&2; failed=1; fi
}

check 'Postfix válido' postfix check
check 'Dovecot válido' bash -c 'doveconf -n >/dev/null'
check 'Postfix activo' systemctl is-active --quiet postfix
check 'Dovecot activo' systemctl is-active --quiet dovecot
check 'Postfix habilitado' systemctl is-enabled --quiet postfix
check 'Dovecot habilitado' systemctl is-enabled --quiet dovecot
for port in 25 587 143; do
  check "puerto ${port} escuchando" bash -c "ss -lnt | grep -Eq '[:.]${port}[[:space:]]'"
done
check 'socket SASL para Postfix' test -S /var/spool/postfix/private/auth
check 'socket LMTP para Postfix' test -S /var/spool/postfix/private/dovecot-lmtp

if [[ -n ${MAIL_TEST_USER} && -n ${MAIL_TEST_PASSWORD} ]]; then
  check 'autenticación LDAP mediante Dovecot' doveadm auth test "${MAIL_TEST_USER}" "${MAIL_TEST_PASSWORD}"
fi
exit "${failed}"
