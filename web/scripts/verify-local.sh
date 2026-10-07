#!/usr/bin/env bash
set -Eeuo pipefail

failed=0

check() {
  local description=$1
  shift
  if "$@"; then
    printf '[PASS] %s\n' "${description}"
  else
    printf '[FAIL] %s\n' "${description}" >&2
    failed=1
  fi
}

check 'configuración válida' apache2ctl -t
check 'servicio activo' systemctl is-active --quiet apache2
check 'servicio habilitado al arranque' systemctl is-enabled --quiet apache2
check 'puerto 80 escuchando' bash -c "ss -lnt | grep -Eq '[:.]80[[:space:]]'"
check 'sitio aerolinea habilitado' test -L /etc/apache2/sites-enabled/aerolinea.conf
for module in ldap authnz_ldap auth_form session_cookie session_crypto include; do
  check "módulo ${module} cargado" bash -c "apache2ctl -M 2>/dev/null | grep -q '${module}_module'"
done
check 'frase de sesión protegida' bash -c "[[ \$(stat -c '%a %U' /etc/apache2/aerolinea-session.key) == '600 root' ]]"
check 'sitio desplegado' test -f /var/www/aerolinea/index.html
check 'servidor LDAP alcanzable' ldapsearch -x -LLL -H ldap://ldap.aerolinea.redes.test -b 'ou=People,dc=aerolinea,dc=redes,dc=test' -s one dn

exit "${failed}"
