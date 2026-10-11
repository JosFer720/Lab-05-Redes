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
WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT
SUBJECT="Lab5-$(date +%s)-${RANDOM}"
BODY="Contenido verificable ${SUBJECT}"
curl() { command curl --connect-timeout 5 --max-time 20 "$@"; }

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
  local code=0
  "$@" >"${WORK_DIR}/rechazo.txt" 2>&1 || code=$?
  if { [[ ${id} == MAIL-04 && ${code} -eq 67 ]]; } ||
     { [[ ${id} == MAIL-07 && ${code} -ne 0 ]] && grep -Eq '550.*(User unknown|Recipient address rejected)' "${WORK_DIR}/rechazo.txt"; }; then
    printf '[PASS] %s %s\n' "${id}" "${description}"
  else
    printf '[FAIL] %s %s: no se confirmó el rechazo esperado (salida %s)\n' "${id}" "${description}" "${code}" >&2
    failed=1
  fi
}

message_received() {
  local attempt answer uid
  for attempt in {1..15}; do
    answer=$(curl --fail --silent --show-error --user "${MAIL_RECIPIENT_USER}:${MAIL_RECIPIENT_PASSWORD}" \
      --request "UID SEARCH SUBJECT \"${SUBJECT}\"" "imap://${MAIL_HOST}/INBOX") || return 1
    uid=$(awk '/^\* SEARCH [0-9]/ {gsub("\r", ""); print $3; exit}' <<< "${answer}")
    if [[ -n ${uid} ]]; then
      curl --fail --silent --show-error --user "${MAIL_RECIPIENT_USER}:${MAIL_RECIPIENT_PASSWORD}" \
        "imap://${MAIL_HOST}/INBOX/;UID=${uid}" | grep -Fq "${BODY}"
      return
    fi
    sleep 1
  done
  return 1
}

send_message() {
  # AUTH en swaks contiene base64 reversible: el transcript queda en un temporal privado.
  swaks --timeout 15 --server "${MAIL_HOST}" --port 587 --auth LOGIN --auth-user "${MAIL_USER}" \
    --auth-password "${MAIL_PASSWORD}" --from "${MAIL_USER}@${DOMAIN}" --to "${MAIL_RECIPIENT}" \
    --header "Subject: ${SUBJECT}" --body "${BODY}" >"${WORK_DIR}/smtp.txt" 2>&1
}

check MAIL-01 'resolución y MX' bash -c "[[ -n \$(dig +short '${MAIL_HOST}' A) ]] && dig +short '${DOMAIN}' MX | grep -q 'mail.${DOMAIN}'"
check MAIL-03 'autenticación IMAP válida' curl --fail --silent --show-error --user "${MAIL_USER}:${MAIL_PASSWORD}" "imap://${MAIL_HOST}/" -o /dev/null
reject MAIL-04 'autenticación IMAP inválida' curl --fail --silent --user "${MAIL_USER}:incorrecta" "imap://${MAIL_HOST}/" -o /dev/null
check MAIL-05 'envío interno autenticado' send_message
check MAIL-06 'mensaje recibido por IMAP' message_received
reject MAIL-07 'destinatario inexistente' swaks --server "${MAIL_HOST}" --port 587 --auth LOGIN --auth-user "${MAIL_USER}" --auth-password "${MAIL_PASSWORD}" --from "${MAIL_USER}@${DOMAIN}" --to "noexiste@${DOMAIN}" --quit-after RCPT
exit "${failed}"
