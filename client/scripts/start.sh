#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Error: ejecute este script con sudo." >&2
  exit 1
fi

DOMAIN=${DOMAIN:-aerolinea.redes.test}
DNS_SERVER=${DNS_SERVER:-}
NETWORK_INTERFACE=${NETWORK_INTERFACE:-}
RUN_TESTS=${RUN_TESTS:-0}
LDAP_USER=${LDAP_USER:-nery}
LDAP_PASSWORD=${LDAP_PASSWORD:-NeryLab5}
WEB_USER=${WEB_USER:-nery}
WEB_PASSWORD=${WEB_PASSWORD:-NeryLab5}
MAIL_USER=${MAIL_USER:-nery}
MAIL_PASSWORD=${MAIL_PASSWORD:-NeryLab5}
MAIL_RECIPIENT=${MAIL_RECIPIENT:-milton@aerolinea.redes.test}
MAIL_RECIPIENT_USER=${MAIL_RECIPIENT_USER:-milton}
MAIL_RECIPIENT_PASSWORD=${MAIL_RECIPIENT_PASSWORD:-MiltonLab5}
FTP_USER=${FTP_USER:-fernando}
FTP_PASSWORD=${FTP_PASSWORD:-FernandoLab5}
GUEST_USER=${GUEST_USER:-guest}
GUEST_PASSWORD=${GUEST_PASSWORD:-GuestLab5}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TEST_DIR=${SCRIPT_DIR}/../tests
export DOMAIN DNS_SERVER LDAP_USER LDAP_PASSWORD WEB_USER WEB_PASSWORD
export MAIL_USER MAIL_PASSWORD MAIL_RECIPIENT MAIL_RECIPIENT_USER
export MAIL_RECIPIENT_PASSWORD FTP_USER FTP_PASSWORD
export GUEST_USER GUEST_PASSWORD

if [[ -z ${DNS_SERVER} ]]; then
  echo "Error: defina DNS_SERVER con la dirección del servidor DNS." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y dnsutils ldap-utils curl swaks

if ! command -v resolvectl >/dev/null 2>&1; then
  echo "Error: el cliente necesita systemd-resolved y resolvectl." >&2
  exit 1
fi

if [[ -z ${NETWORK_INTERFACE} ]]; then
  NETWORK_INTERFACE=$(ip route show default | awk 'NR == 1 {print $5}')
fi
if [[ -z ${NETWORK_INTERFACE} || ! -d /sys/class/net/${NETWORK_INTERFACE} ]]; then
  echo "Error: no se pudo identificar la interfaz de red." >&2
  exit 1
fi

systemctl enable --now systemd-resolved
resolvectl dns "${NETWORK_INTERFACE}" "${DNS_SERVER}"
resolvectl domain "${NETWORK_INTERFACE}" "~${DOMAIN}"
resolvectl flush-caches

if ! dig +short "@${DNS_SERVER}" "ns1.${DOMAIN}" A | grep -q .; then
  echo "Error: el DNS no responde por la dirección ${DNS_SERVER}." >&2
  exit 1
fi
if ! getent hosts "ldap.${DOMAIN}" >/dev/null; then
  echo "Error: el sistema todavía no resuelve el dominio del laboratorio." >&2
  exit 1
fi

echo "Cliente preparado en ${NETWORK_INTERFACE}."
echo "DNS del laboratorio: ${DNS_SERVER}"
echo "Dominio del laboratorio: ${DOMAIN}"
echo
echo "Acceso para usuario invitado"
echo "Usuario: ${GUEST_USER}"
echo "Clave: ${GUEST_PASSWORD}"
echo "Web: http://www.${DOMAIN}"
echo "Correo: ${GUEST_USER}@${DOMAIN}"
echo "IMAP: mail.${DOMAIN} puerto 143"
echo "SMTP: mail.${DOMAIN} puerto 587"
echo "FTP: ftp.${DOMAIN} puerto 21"

if [[ ${RUN_TESTS} == 1 ]]; then
  "${TEST_DIR}/test-all.sh"
else
  echo "El cliente está listo para utilizar los servicios."
fi
