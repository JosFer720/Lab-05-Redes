#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Error: ejecute este script con sudo." >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DOMAIN=${DOMAIN:-aerolinea.redes.test}
MAIL_TEST_USER=${MAIL_TEST_USER:-nery}
MAIL_TEST_PASSWORD=${MAIL_TEST_PASSWORD:-NeryLab5}
export MAIL_TEST_USER MAIL_TEST_PASSWORD

if ! command -v postfix >/dev/null 2>&1 || ! command -v doveconf >/dev/null 2>&1 ||
   ! grep -Fq "virtual_mailbox_domains = ${DOMAIN}" /etc/postfix/main.cf 2>/dev/null; then
  echo "Correo no está configurado. Ejecutando instalación inicial."
  "${SCRIPT_DIR}/install.sh"
else
  postfix check
  doveconf -n >/dev/null
  systemctl enable postfix dovecot
  systemctl restart postfix dovecot
fi

"${SCRIPT_DIR}/verify-local.sh"
echo "Correo disponible en SMTP 25 y 587 e IMAP 143."
echo "Usuario de comprobación: ${MAIL_TEST_USER}"
