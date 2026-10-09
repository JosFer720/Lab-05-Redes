#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN=${DOMAIN:-aerolinea.redes.test}
FTP_HOST=${FTP_HOST:-ftp.${DOMAIN}}
FTP_USER=${FTP_USER:-fernando}
FTP_PASSWORD=${FTP_PASSWORD:-FernandoLab5}
WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

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
run_fail() {
  local id=$1 description=$2
  shift 2
  if "$@"; then
    printf '[FAIL] %s %s: se esperaba rechazo\n' "${id}" "${description}" >&2
    ((failed+=1))
  else
    printf '[PASS] %s %s\n' "${id}" "${description}"
    ((passed+=1))
  fi
}

printf 'prueba ftp %s\n' "$(date --iso-8601=seconds 2>/dev/null || date)" > "${WORK_DIR}/prueba.txt"

run_pass FTP-01 'resolución DNS' getent hosts "${FTP_HOST}"
run_pass FTP-02 'autenticación válida' curl --fail --silent --show-error --user "${FTP_USER}:${FTP_PASSWORD}" "ftp://${FTP_HOST}/" -o "${WORK_DIR}/listado.txt"
run_fail FTP-03 'contraseña incorrecta' curl --fail --silent --user "${FTP_USER}:incorrecta" "ftp://${FTP_HOST}/" -o /dev/null
run_fail FTP-04 'acceso anónimo' curl --fail --silent --user 'anonymous:a@a.com' "ftp://${FTP_HOST}/" -o /dev/null
run_pass FTP-05 'listado de directorio' grep -q 'bienvenida.txt' "${WORK_DIR}/listado.txt"
run_pass FTP-06 'carga de archivo' curl --fail --silent --show-error --user "${FTP_USER}:${FTP_PASSWORD}" -T "${WORK_DIR}/prueba.txt" "ftp://${FTP_HOST}/uploads/prueba.txt"
run_pass FTP-07 'descarga de archivo' curl --fail --silent --show-error --user "${FTP_USER}:${FTP_PASSWORD}" "ftp://${FTP_HOST}/uploads/prueba.txt" -o "${WORK_DIR}/descargado.txt"
run_pass FTP-07b 'integridad de descarga' cmp "${WORK_DIR}/prueba.txt" "${WORK_DIR}/descargado.txt"
run_fail FTP-08 'salida de la jaula' curl --fail --silent --user "${FTP_USER}:${FTP_PASSWORD}" "ftp://${FTP_HOST}/etc/passwd" -o /dev/null

printf '\nResultado: %d PASS, %d FAIL\n' "${passed}" "${failed}"
(( failed == 0 ))
