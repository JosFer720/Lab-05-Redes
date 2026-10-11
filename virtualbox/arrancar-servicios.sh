#!/usr/bin/env bash
set -Eeuo pipefail
systemctl enable --now named slapd apache2 postfix dovecot vsftpd
systemctl is-active named slapd apache2 postfix dovecot vsftpd
