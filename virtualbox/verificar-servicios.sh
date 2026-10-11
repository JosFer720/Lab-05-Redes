#!/usr/bin/env bash
set -Eeuo pipefail
hostnamectl
ip -br link
ip -br addr
ip route
ip neigh
systemctl is-enabled named slapd apache2 postfix dovecot vsftpd
systemctl is-active named slapd apache2 postfix@- dovecot vsftpd
named-checkconf
named-checkzone aerolinea.redes.test /etc/bind/zones/db.aerolinea.redes.test
apache2ctl configtest
postfix check
doveconf -n
ss -lntup
