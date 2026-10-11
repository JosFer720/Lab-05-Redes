#!/usr/bin/env bash
set -Eeuo pipefail
systemctl stop vsftpd dovecot postfix apache2 slapd named
