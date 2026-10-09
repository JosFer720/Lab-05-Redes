#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN=${DOMAIN:-aerolinea.redes.test}
BASE_DN=${BASE_DN:-dc=aerolinea,dc=redes,dc=test}
LDAP_HOST=${LDAP_HOST:-ldap.${DOMAIN}}
TEMPLATES=/opt/mail-templates

if ! getent group vmail >/dev/null; then
  groupadd -g 5000 vmail
fi
if ! getent passwd vmail >/dev/null; then
  useradd -u 5000 -g vmail -d /var/mail/vhosts -s /usr/sbin/nologin vmail
fi

install -d -o vmail -g vmail -m 0750 "/var/mail/vhosts/${DOMAIN}"
chown -R vmail:vmail /var/mail/vhosts

sed -e "s|DOMAIN|${DOMAIN}|g" \
  "${TEMPLATES}/postfix/main.cf" > /etc/postfix/main.cf
sed -e "s|ldap.DOMAIN|${LDAP_HOST}|g" \
    -e "s|DOMAIN|${DOMAIN}|g" \
    -e "s|BASE_DN|${BASE_DN}|g" \
  "${TEMPLATES}/postfix/ldap-virtual-mailbox.cf" > /etc/postfix/ldap-virtual-mailbox.cf
chown root:postfix /etc/postfix/ldap-virtual-mailbox.cf
chmod 0640 /etc/postfix/ldap-virtual-mailbox.cf

# No usamos chroot dentro del contenedor; asi Postfix puede consultar LDAP y
# compartir los sockets de autenticacion y LMTP creados por Dovecot.
postconf -M "smtp/inet=smtp inet n - n - - smtpd"
postconf -M "submission/inet=submission inet n - n - - smtpd"
postconf -P "submission/inet/syslog_name=postfix/submission"
postconf -P "submission/inet/smtpd_sasl_auth_enable=yes"
postconf -P "submission/inet/smtpd_recipient_restrictions=permit_sasl_authenticated,reject"
postconf -P "submission/inet/smtpd_relay_restrictions=permit_sasl_authenticated,reject"
postconf -e "maillog_file=/dev/stdout"

sed -e "s|DOMAIN|${DOMAIN}|g" \
  "${TEMPLATES}/dovecot/10-auth.conf" > /etc/dovecot/conf.d/10-auth.conf
sed -e "s|DOMAIN|${DOMAIN}|g" \
  "${TEMPLATES}/dovecot/auth-ldap.conf.ext" > /etc/dovecot/conf.d/auth-ldap.conf.ext
sed -e "s|ldap.DOMAIN|${LDAP_HOST}|g" \
    -e "s|DOMAIN|${DOMAIN}|g" \
    -e "s|BASE_DN|${BASE_DN}|g" \
  "${TEMPLATES}/dovecot/dovecot-ldap.conf.ext" > /etc/dovecot/dovecot-ldap.conf.ext
sed -e "s|DOMAIN|${DOMAIN}|g" \
  "${TEMPLATES}/dovecot/99-aerolinea.conf" > /etc/dovecot/conf.d/99-aerolinea.conf
cat >> /etc/dovecot/conf.d/99-aerolinea.conf <<'EOF'
log_path = /dev/stderr
info_log_path = /dev/stdout
EOF
chown root:dovecot /etc/dovecot/dovecot-ldap.conf.ext
chmod 0640 /etc/dovecot/dovecot-ldap.conf.ext

postfix check
doveconf -n >/dev/null

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
