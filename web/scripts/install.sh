#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Error: ejecute este script con sudo." >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SOURCE_CONFIG=${SCRIPT_DIR}/../config/aerolinea.conf
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

rm -rf "${WEB_ROOT}"
install -d -o root -g root -m 0755 "${WEB_ROOT}"
cp -r "${SITE_DIST}/." "${WEB_ROOT}/"
chown -R root:root "${WEB_ROOT}"
find "${WEB_ROOT}" -type d -exec chmod 0755 {} +
find "${WEB_ROOT}" -type f -exec chmod 0644 {} +

install -o root -g root -m 0644 "${SOURCE_CONFIG}" /etc/apache2/sites-available/aerolinea.conf
a2dissite 000-default >/dev/null || true
a2ensite aerolinea

apache2ctl configtest
systemctl enable --now apache2
systemctl restart apache2
systemctl --no-pager --full status apache2
echo "Apache instalado. UFW no fue modificado."
