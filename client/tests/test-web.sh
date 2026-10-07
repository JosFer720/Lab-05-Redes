#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN=${DOMAIN:-aerolinea.redes.test}
WEB_HOST=${WEB_HOST:-www.${DOMAIN}}
WEB_URL=http://${WEB_HOST}
WEB_USER=${WEB_USER:-}
WEB_PASSWORD=${WEB_PASSWORD:-}
WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

if [[ -z ${WEB_USER} || -z ${WEB_PASSWORD} ]]; then
  echo "Error: defina WEB_USER y WEB_PASSWORD con un usuario LDAP válido." >&2
  exit 1
fi

passed=0
failed=0
run_pass() {
  local id=$1 description=$2
  shift 2
  if "$@"; then
    printf '[PASS] %s %s\n' "${id}" "${description}"
    ((passed+=1))
  else
    printf '[FAIL] %s %s\n' "${id}" "${description}" >&2
    ((failed+=1))
  fi
}

login_redirect() {
  curl --silent --output /dev/null --write-out '%{redirect_url}' \
    --cookie-jar "$3" \
    --data-urlencode "httpd_username=$1" \
    --data-urlencode "httpd_password=$2" \
    "${WEB_URL}/dologin"
}

redirects_to() {
  [[ $(curl --silent --output /dev/null --write-out '%{redirect_url}' --cookie "$2" "$1") == *"$3" ]]
}

login_accepted() {
  [[ $(login_redirect "${WEB_USER}" "${WEB_PASSWORD}" "${WORK_DIR}/valida.txt") == */privado/ ]]
}

login_rejected() {
  [[ $(login_redirect "$1" "$2" "${WORK_DIR}/rechazada.txt") == */login/?error=1 ]]
}

private_shows_user() {
  curl --fail --silent --show-error --cookie "${WORK_DIR}/valida.txt" "${WEB_URL}/privado/usuario.json" |
    grep -q "\"uid\": \"${WEB_USER}\""
}

touch "${WORK_DIR}/vacia.txt"

run_pass WEB-01 'resolución DNS' bash -c "[[ -n \$(dig +short '${WEB_HOST}' A) ]]"
run_pass WEB-02 'página principal' bash -c "curl --fail --silent '${WEB_URL}/' | grep -q 'Aerolínea Redes'"
run_pass WEB-03a 'área privada exige login' redirects_to "${WEB_URL}/privado/" "${WORK_DIR}/vacia.txt" /login/
run_pass WEB-03b 'login LDAP válido' login_accepted
run_pass WEB-03c 'acceso con sesión' private_shows_user
run_pass WEB-04a 'contraseña incorrecta rechazada' login_rejected "${WEB_USER}" incorrecta
run_pass WEB-04b 'usuario inexistente rechazado' login_rejected noexiste incorrecta
run_pass WEB-04c 'logout cierra la sesión' bash -c "curl --silent --output /dev/null --cookie '${WORK_DIR}/valida.txt' --cookie-jar '${WORK_DIR}/valida.txt' '${WEB_URL}/logout'"
run_pass WEB-04d 'sin acceso tras logout' redirects_to "${WEB_URL}/privado/" "${WORK_DIR}/valida.txt" /login/

printf '\nResultado: %d PASS, %d FAIL\n' "${passed}" "${failed}"
(( failed == 0 ))
