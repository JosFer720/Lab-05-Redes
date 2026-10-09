#!/usr/bin/env bash
set -Eeuo pipefail
/usr/sbin/slapd -h 'ldap://0.0.0.0:389/' -u openldap -g openldap -d 0 &
pid=$!
trap 'kill ${pid}' TERM INT
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  ldapsearch -x -H ldap://127.0.0.1 -b 'dc=aerolinea,dc=redes,dc=test' -s base dn >/dev/null 2>&1 && break
  sleep 1
done
if ! ldapsearch -x -H ldap://127.0.0.1 -b 'ou=People,dc=aerolinea,dc=redes,dc=test' -s base dn >/dev/null 2>&1; then
  ldapadd -x -H ldap://127.0.0.1 -D 'cn=admin,dc=aerolinea,dc=redes,dc=test' -w AdminLDAP -f /opt/users.ldif
fi
wait "${pid}"
