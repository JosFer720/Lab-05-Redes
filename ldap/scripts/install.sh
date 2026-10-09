#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Error: ejecute este script con sudo." >&2
  exit 1
fi

DOMAIN=${DOMAIN:-aerolinea.redes.test}
BASE_DN=${BASE_DN:-dc=aerolinea,dc=redes,dc=test}
ORG_NAME=${ORG_NAME:-Aerolinea}
LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD:-}
USERS_FILE=${USERS_FILE:-}
RECONFIGURE_LDAP=${RECONFIGURE_LDAP:-0}

if [[ -z ${LDAP_ADMIN_PASSWORD} || -z ${USERS_FILE} ]]; then
  echo "Error: defina LDAP_ADMIN_PASSWORD y USERS_FILE." >&2
  exit 1
fi
if [[ ! -r ${USERS_FILE} ]]; then
  echo "Error: no se puede leer USERS_FILE." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
SLAPD_WAS_INSTALLED=0
dpkg-query -W -f='${Status}' slapd 2>/dev/null | grep -q 'install ok installed' && SLAPD_WAS_INSTALLED=1
debconf-set-selections <<EOF
slapd slapd/no_configuration boolean false
slapd slapd/domain string ${DOMAIN}
slapd shared/organization string ${ORG_NAME}
slapd slapd/password1 password ${LDAP_ADMIN_PASSWORD}
slapd slapd/password2 password ${LDAP_ADMIN_PASSWORD}
slapd slapd/backend select MDB
slapd slapd/purge_database boolean false
slapd slapd/move_old_database boolean true
slapd slapd/allow_ldap_v2 boolean false
EOF

apt-get update
apt-get install -y slapd ldap-utils
if (( SLAPD_WAS_INSTALLED == 1 )) && [[ ${RECONFIGURE_LDAP} == 1 ]]; then
  dpkg-reconfigure -f noninteractive slapd
fi
systemctl enable --now slapd

ADMIN_DN="cn=admin,${BASE_DN}"
TMP_LDIF=$(mktemp)
trap 'rm -f "${TMP_LDIF}"' EXIT
chmod 0600 "${TMP_LDIF}"

if ! ldapsearch -x -LLL -H ldap://127.0.0.1 -D "${ADMIN_DN}" -w "${LDAP_ADMIN_PASSWORD}" -b "ou=People,${BASE_DN}" -s base dn >/dev/null 2>&1; then
  cat > "${TMP_LDIF}" <<EOF
dn: ou=People,${BASE_DN}
objectClass: organizationalUnit
ou: People
EOF
  ldapadd -x -H ldap://127.0.0.1 -D "${ADMIN_DN}" -w "${LDAP_ADMIN_PASSWORD}" -f "${TMP_LDIF}"
fi

while IFS=$'\t' read -r uid cn sn mail password extra; do
  [[ -z ${uid} || ${uid} == \#* ]] && continue
  if [[ -z ${cn} || -z ${sn} || -z ${mail} || -z ${password} || -n ${extra:-} ]]; then
    echo "Error: fila inválida para ${uid}. Se esperan cinco columnas." >&2
    exit 1
  fi
  if [[ ! ${uid} =~ ^[a-z][a-z0-9._-]*$ ]]; then
    echo "Error: uid inválido: ${uid}." >&2
    exit 1
  fi

  USER_DN="uid=${uid},ou=People,${BASE_DN}"
  PASSWORD_HASH=$(slappasswd -h '{SSHA}' -s "${password}")
  cat > "${TMP_LDIF}" <<EOF
dn: ${USER_DN}
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
uid: ${uid}
cn: ${cn}
sn: ${sn}
mail: ${mail}
userPassword: ${PASSWORD_HASH}
EOF

  if ldapsearch -x -LLL -H ldap://127.0.0.1 -D "${ADMIN_DN}" -w "${LDAP_ADMIN_PASSWORD}" -b "${USER_DN}" -s base dn >/dev/null 2>&1; then
    sed '1d; s/^userPassword:/replace: userPassword\nuserPassword:/' "${TMP_LDIF}" > "${TMP_LDIF}.modify"
    {
      printf 'dn: %s\nchangetype: modify\n' "${USER_DN}"
      grep -A1 '^replace: userPassword' "${TMP_LDIF}.modify"
      printf -- '-\nreplace: cn\ncn: %s\n-\nreplace: sn\nsn: %s\n-\nreplace: mail\nmail: %s\n' "${cn}" "${sn}" "${mail}"
    } > "${TMP_LDIF}"
    rm -f "${TMP_LDIF}.modify"
    ldapmodify -x -H ldap://127.0.0.1 -D "${ADMIN_DN}" -w "${LDAP_ADMIN_PASSWORD}" -f "${TMP_LDIF}"
  else
    ldapadd -x -H ldap://127.0.0.1 -D "${ADMIN_DN}" -w "${LDAP_ADMIN_PASSWORD}" -f "${TMP_LDIF}"
  fi
done < "${USERS_FILE}"

systemctl restart slapd
systemctl --no-pager --full status slapd
