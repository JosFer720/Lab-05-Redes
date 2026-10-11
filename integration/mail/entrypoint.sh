#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p /var/spool/postfix/private
postconf -e 'maillog_file=/var/log/postfix.log'
if ! grep -q '^log_path = /dev/stderr' /etc/dovecot/conf.d/99-aerolinea.conf; then
  printf '\nlog_path = /dev/stderr\ninfo_log_path = /dev/stdout\n' >> /etc/dovecot/conf.d/99-aerolinea.conf
fi
/usr/sbin/dovecot -F &
pid=$!
trap 'postfix stop || true; kill ${pid} || true' TERM INT
postfix start
wait "${pid}"
