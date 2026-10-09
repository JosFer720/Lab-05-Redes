#!/usr/bin/env bash
set -Eeuo pipefail

postfix status >/dev/null 2>&1
doveadm service status >/dev/null 2>&1
nc -z 127.0.0.1 25
nc -z 127.0.0.1 143
nc -z 127.0.0.1 587
test -S /var/spool/postfix/private/auth
test -S /var/spool/postfix/private/dovecot-lmtp
