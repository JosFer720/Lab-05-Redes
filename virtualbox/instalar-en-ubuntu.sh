#!/usr/bin/env bash
# Instala el laboratorio completo (DNS, LDAP, web, correo, FTP) en ESTE Ubuntu 24.04, sea una VM de cualquier
# hipervisor (VirtualBox, UTM, VMware, Parallels...) o un equipo real. Sirve cuando no se usa Windows + VirtualBox.
# La VM debe tener la red en PUENTE (bridged) para que los demás equipos de la red la alcancen.
#
# Uso, dentro del Ubuntu y desde la carpeta del repositorio:
#   sudo bash virtualbox/instalar-en-ubuntu.sh
#   sudo bash virtualbox/instalar-en-ubuntu.sh --credenciales /ruta/credentials.json
#   sudo bash virtualbox/instalar-en-ubuntu.sh --interfaz enp0s1 --solo-preparar
#
# Opciones:
#   --credenciales FILE  usa ese credentials.json; sin la opción se genera uno nuevo con claves aleatorias
#   --interfaz IFACE     interfaz de red del puente (predeterminado: la de la ruta por defecto)
#   --solo-preparar      calcula IP/red y deja listos los archivos privados, pero no instala nada
# Si cambia la IP o la red: sudo bash virtualbox/cambiar-ip.sh
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Ejecute con sudo' >&2; exit 1; }
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PRIV=/root/lab5-private
CREDS=''
IFACE=''
ONLY_PREPARE=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --credenciales) CREDS=${2:?falta la ruta}; shift 2 ;;
    --interfaz) IFACE=${2:?falta el nombre de la interfaz}; shift 2 ;;
    --solo-preparar) ONLY_PREPARE=1; shift ;;
    -h|--help) sed -n '2,16p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; exit 1 ;;
  esac
done
[[ $(lsb_release -rs 2>/dev/null || echo '?') == 24.04 ]] || echo 'Aviso: se probó en Ubuntu 24.04; otra versión puede fallar.' >&2

# Si el repositorio vino de Windows (Git con autocrlf, un zip), los archivos de texto pueden traer saltos CRLF y en
# Linux fallan (por ejemplo vsftpd.conf deja de arrancar): se convierten a LF antes de instalar.
mapfile -t crlf_files < <(find "$ROOT/dns" "$ROOT/ldap" "$ROOT/web" "$ROOT/mail" "$ROOT/ftp" "$ROOT/virtualbox" "$ROOT/client" \
  -type f \( -name '*.sh' -o -name '*.conf' -o -name '*.cf' -o -name '*.ext' -o -name '*.ldif' -o -name '*.py' -o -name '*.tsv' \
  -o -name '*.txt' -o -name '*.json' -o -name '*.ts' -o -name '*.tsx' -o -name '*.html' -o -name '*.css' \) \
  -not -path '*/node_modules/*' -not -path '*/dist/*' -exec grep -lI $'\r' {} + 2>/dev/null || true)
if (( ${#crlf_files[@]} )); then
  sed -i 's/\r$//' "${crlf_files[@]}"
  echo "Se convirtieron ${#crlf_files[@]} archivos de CRLF a LF."
fi

IFACE=${IFACE:-$(ip route show default | awk 'NR==1 {print $5}')}
[[ -n $IFACE && -d /sys/class/net/$IFACE ]] || { echo 'No encuentro la interfaz de red; use --interfaz' >&2; exit 1; }
CIDR=$(ip -4 -o addr show dev "$IFACE" scope global | awk 'NR==1 {print $4}')
[[ ${CIDR:-} =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]] || { echo "La interfaz $IFACE no tiene IPv4: conéctela a la red (puente) y repita." >&2; exit 1; }
LAB_IP=${CIDR%/*}
LAB_NETWORK=$(python3 -c 'import ipaddress,sys; print(ipaddress.ip_interface(sys.argv[1]).network)' "$CIDR")
echo "Interfaz: $IFACE   IP: $LAB_IP   red: $LAB_NETWORK   MAC: $(cat "/sys/class/net/$IFACE/address")"

install -d -m 0700 "$PRIV"
if [[ -n $CREDS ]]; then
  install -m 0600 "$CREDS" "$PRIV/credentials.json"
elif [[ ! -f $PRIV/credentials.json ]]; then
  python3 "$ROOT/virtualbox/generar-credenciales.py" --salida "$PRIV/credentials.json"
else
  echo "Se conservan las credenciales existentes en $PRIV/credentials.json"
fi

# Equivale a lo que hace virtualbox/desplegar.py desde Windows: users.tsv para LDAP y deploy.env para el instalador.
LAB_IP=$LAB_IP LAB_NETWORK=$LAB_NETWORK LAB_IFACE=$IFACE ROOT=$ROOT PRIV=$PRIV python3 - <<'PY'
import json, os, re, shlex
from pathlib import Path
root, priv = Path(os.environ['ROOT']), Path(os.environ['PRIV'])
credentials = json.loads((priv / 'credentials.json').read_text(encoding='utf8'))
ldif = (root / 'ldap/ldif/usuarios-laboratorio.ldif').read_text(encoding='utf8')
rows = []
for block in ldif.split('\n\n'):
    attrs = dict(re.findall(r'^(uid|cn|sn|mail): (.+)$', block, re.M))
    if 'uid' in attrs:
        rows.append('\t'.join([attrs[k] for k in ('uid', 'cn', 'sn', 'mail')] + [credentials['passwords'][attrs['uid']]]))
(priv / 'users.tsv').write_text('\n'.join(rows) + '\n', encoding='utf8')
env = {'LDAP_ADMIN_PASSWORD': credentials['admin_password'], 'USERS_FILE': str(priv / 'users.tsv'),
       'FTP_USER': credentials['ftp_user'], 'FTP_PASSWORD': credentials['ftp_password'],
       'LAB_IP': os.environ['LAB_IP'], 'LAB_NETWORK': os.environ['LAB_NETWORK'], 'LAB_IFACE': os.environ['LAB_IFACE'],
       'LAB_RESOLVER': '127.0.0.1', 'LAB_PORTS': '22 53 80 389 25 587 143 21'}
(priv / 'deploy.env').write_text(''.join(f'export {k}={shlex.quote(v)}\n' for k, v in env.items()), encoding='utf8')
print(f'{len(rows)} usuarios LDAP preparados.')
PY
chmod 600 "$PRIV"/users.tsv "$PRIV"/deploy.env

if [[ $ONLY_PREPARE == 1 ]]; then
  echo 'Archivos privados listos en '"$PRIV"' (no se instaló nada).'
  exit 0
fi
PRIVATE_ENV=$PRIV/deploy.env bash "$ROOT/virtualbox/instalar-servicios.sh"

echo
echo "Listo. IP de los servicios: $LAB_IP   MAC ($IFACE): $(cat "/sys/class/net/$IFACE/address")"
echo "Los demás equipos usan $LAB_IP como DNS. Credenciales para ellos: $PRIV/credentials.json (entréguelas por un canal privado)."
echo "Si cambia la IP o la red: sudo bash $ROOT/virtualbox/cambiar-ip.sh"
