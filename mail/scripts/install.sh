#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Error: ejecute este script con sudo." >&2
  exit 1
fi

DOMAIN=${DOMAIN:-aerolinea.redes.test}
BASE_DN=${BASE_DN:-dc=aerolinea,dc=redes,dc=test}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CONFIG_DIR=${SCRIPT_DIR}/../config
export DEBIAN_FRONTEND=noninteractive

echo "postfix postfix/mailname string ${DOMAIN}" | debconf-set-selections
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
apt-get update
apt-get install -y postfix postfix-ldap dovecot-core dovecot-imapd dovecot-ldap dovecot-lmtpd ldap-utils curl swaks

if ! getent group vmail >/dev/null; then
  groupadd -g 5000 vmail
fi
if ! getent passwd vmail >/dev/null; then
  useradd -u 5000 -g vmail -d /var/mail/vhosts -s /usr/sbin/nologin vmail
fi
install -d -o vmail -g vmail -m 0750 "/var/mail/vhosts/${DOMAIN}"

for file in /etc/postfix/main.cf /etc/postfix/master.cf /etc/dovecot/conf.d/10-auth.conf; do
  [[ -f ${file} ]] && cp -a "${file}" "${file}.bak.$(date +%Y%m%d%H%M%S)"
done

sed -e "s|DOMAIN|${DOMAIN}|g" "${CONFIG_DIR}/postfix/main.cf" > /etc/postfix/main.cf
sed -e "s|DOMAIN|${DOMAIN}|g" -e "s|BASE_DN|${BASE_DN}|g" \
  "${CONFIG_DIR}/postfix/ldap-virtual-mailbox.cf" > /etc/postfix/ldap-virtual-mailbox.cf
chown root:postfix /etc/postfix/ldap-virtual-mailbox.cf
chmod 0640 /etc/postfix/ldap-virtual-mailbox.cf

sed -i '/^# BEGIN AEROLINEA$/,/^# END AEROLINEA$/d' /etc/postfix/master.cf
{
  printf '\n# BEGIN AEROLINEA\n'
  cat "${CONFIG_DIR}/postfix/submission.master.cf"
  printf '# END AEROLINEA\n'
} >> /etc/postfix/master.cf

sed -e "s|DOMAIN|${DOMAIN}|g" "${CONFIG_DIR}/dovecot/10-auth.conf" > /etc/dovecot/conf.d/10-auth.conf
sed -e "s|DOMAIN|${DOMAIN}|g" "${CONFIG_DIR}/dovecot/auth-ldap.conf.ext" > /etc/dovecot/conf.d/auth-ldap.conf.ext
sed -e "s|DOMAIN|${DOMAIN}|g" -e "s|BASE_DN|${BASE_DN}|g" \
  "${CONFIG_DIR}/dovecot/dovecot-ldap.conf.ext" > /etc/dovecot/dovecot-ldap.conf.ext
sed -e "s|DOMAIN|${DOMAIN}|g" "${CONFIG_DIR}/dovecot/99-aerolinea.conf" > /etc/dovecot/conf.d/99-aerolinea.conf
chown root:dovecot /etc/dovecot/dovecot-ldap.conf.ext
chmod 0640 /etc/dovecot/dovecot-ldap.conf.ext

postfix check
doveconf -n >/dev/null
systemctl enable --now postfix dovecot
systemctl restart postfix dovecot
systemctl --no-pager --full status postfix dovecot
