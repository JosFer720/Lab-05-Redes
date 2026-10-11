#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Error: ejecute este script con sudo." >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SOURCE_CONFIG=${SCRIPT_DIR}/../config/aerolinea.conf
LDAP_HOST=${LDAP_HOST:-ldap.aerolinea.redes.test}
LDAP_PORT=${LDAP_PORT:-389}
if [[ ! ${LDAP_HOST} =~ ^[a-zA-Z0-9.-]+$ || ! ${LDAP_PORT} =~ ^[0-9]{1,5}$ ]] ||
   (( 10#${LDAP_PORT} < 1 || 10#${LDAP_PORT} > 65535 )); then
  echo 'Error: LDAP_HOST o LDAP_PORT inválido.' >&2
  exit 1
fi
SITE_DIST=${SITE_DIST:-${SCRIPT_DIR}/../site/dist}
WEB_ROOT=/var/www/aerolinea
SESSION_KEY=/etc/apache2/aerolinea-session.key
export DEBIAN_FRONTEND=noninteractive

if [[ ! -f ${SITE_DIST}/index.html ]]; then
  echo "Error: no existe ${SITE_DIST}/index.html. Compile el sitio con 'npm run build' en web/site." >&2
  exit 1
fi

apt-get update
apt-get install -y apache2 openssl curl ldap-utils

a2enmod ldap authnz_ldap auth_form request session session_cookie session_crypto include

if [[ ! -f ${SESSION_KEY} ]]; then
  openssl rand -base64 48 > "${SESSION_KEY}"
fi
chown root:root "${SESSION_KEY}"
chmod 0600 "${SESSION_KEY}"

BACKUP_DIR=/var/backups/aerolinea/$(date +%Y%m%d%H%M%S)
install -d -m 0700 "${BACKUP_DIR}"
[[ ! -d ${WEB_ROOT} ]] || cp -a "${WEB_ROOT}" "${BACKUP_DIR}/site"
[[ ! -f /etc/apache2/sites-available/aerolinea.conf ]] || cp -a /etc/apache2/sites-available/aerolinea.conf "${BACKUP_DIR}/aerolinea.conf"
rm -rf "${WEB_ROOT}"
install -d -o root -g root -m 0755 "${WEB_ROOT}"
cp -r "${SITE_DIST}/." "${WEB_ROOT}/"
chown -R root:root "${WEB_ROOT}"
find "${WEB_ROOT}" -type d -exec chmod 0755 {} +
find "${WEB_ROOT}" -type f -exec chmod 0644 {} +

sed "s|ldap://ldap.aerolinea.redes.test/|ldap://${LDAP_HOST}:${LDAP_PORT}/|g" "${SOURCE_CONFIG}" > /etc/apache2/sites-available/aerolinea.conf
chown root:root /etc/apache2/sites-available/aerolinea.conf
chmod 0644 /etc/apache2/sites-available/aerolinea.conf
a2dissite 000-default >/dev/null || true
a2ensite aerolinea

apache2ctl configtest
systemctl enable --now apache2
systemctl restart apache2
systemctl --no-pager --full status apache2
echo "Apache instalado. UFW no fue modificado."
