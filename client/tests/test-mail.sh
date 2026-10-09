#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN=${DOMAIN:-aerolinea.redes.test}
MAIL_HOST=${MAIL_HOST:-mail.${DOMAIN}}
MAIL_USER=${MAIL_USER:-}
MAIL_PASSWORD=${MAIL_PASSWORD:-}
MAIL_RECIPIENT=${MAIL_RECIPIENT:-}
MAIL_RECIPIENT_USER=${MAIL_RECIPIENT_USER:-}
MAIL_RECIPIENT_PASSWORD=${MAIL_RECIPIENT_PASSWORD:-}
failed=0

if [[ -z ${MAIL_USER} || -z ${MAIL_PASSWORD} || -z ${MAIL_RECIPIENT} ||
      -z ${MAIL_RECIPIENT_USER} || -z ${MAIL_RECIPIENT_PASSWORD} ]]; then
  echo "Error: faltan variables de remitente o destinatario." >&2
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
  if "$@" >/dev/null 2>&1; then printf '[FAIL] %s %s\n' "${id}" "${description}" >&2; failed=1; else printf '[PASS] %s %s\n' "${id}" "${description}"; fi
}

message_received() {
  curl --fail --silent --show-error \
    --user "${MAIL_RECIPIENT_USER}:${MAIL_RECIPIENT_PASSWORD}" \
    --request 'SEARCH SUBJECT "Prueba interna"' \
    "imap://${MAIL_HOST}/INBOX" | grep -Eq 'SEARCH[[:space:]]+[0-9]'
}

check MAIL-01 'resolución y MX' bash -c "[[ -n \$(dig +short '${MAIL_HOST}' A) ]] && dig +short '${DOMAIN}' MX | grep -q 'mail.${DOMAIN}'"
check MAIL-03 'autenticación IMAP válida' curl --fail --silent --show-error --user "${MAIL_USER}:${MAIL_PASSWORD}" "imap://${MAIL_HOST}/" -o /dev/null
reject MAIL-04 'autenticación IMAP inválida' curl --fail --silent --user "${MAIL_USER}:incorrecta" "imap://${MAIL_HOST}/" -o /dev/null
check MAIL-05 'envío interno autenticado' swaks --server "${MAIL_HOST}" --port 587 --auth LOGIN --auth-user "${MAIL_USER}" --auth-password "${MAIL_PASSWORD}" --from "${MAIL_USER}@${DOMAIN}" --to "${MAIL_RECIPIENT}" --header 'Subject: Prueba interna' --body 'Mensaje de prueba interna'
check MAIL-06 'mensaje recibido por IMAP' message_received
reject MAIL-07 'destinatario inexistente' swaks --server "${MAIL_HOST}" --port 587 --auth LOGIN --auth-user "${MAIL_USER}" --auth-password "${MAIL_PASSWORD}" --from "${MAIL_USER}@${DOMAIN}" --to "noexiste@${DOMAIN}" --quit-after RCPT
exit "${failed}"
