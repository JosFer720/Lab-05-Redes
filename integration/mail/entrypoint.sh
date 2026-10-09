#!/usr/bin/env bash
set -Eeuo pipefail
mkdir -p /var/spool/postfix/private
/usr/sbin/dovecot -F &
pid=$!
trap 'postfix stop || true; kill ${pid} || true' TERM INT
postfix start
wait "${pid}"
