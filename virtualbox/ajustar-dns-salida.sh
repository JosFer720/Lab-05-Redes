#!/usr/bin/env bash
# Hace que BIND resuelva nombres de Internet en la red actual (los clientes que usan este DNS como general lo notan).
# Los hotspots de celular y muchas redes bloquean 1.1.1.1 o dejan sin respuesta las consultas DNSSEC hacia DNS
# públicos: BIND da SERVFAIL ("broken trust chain", "timed out resolving ./DNSKEY"). Este script pone primero los DNS
# que entrega el DHCP de la red (adaptador en puente) como reenviadores y desactiva la validación DNSSEC
# (la zona del laboratorio es local y no usa DNSSEC). Si el adaptador no recibió DNS por DHCP (por ejemplo host-only
# con IP fija) no cambia nada.
# Uso, dentro de la VM:  sudo bash /opt/lab5/virtualbox/ajustar-dns-salida.sh      (cambiar-ip.sh ya lo ejecuta)
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Ejecute con sudo' >&2; exit 1; }
[[ -f /root/lab5-private/red.env ]] && source /root/lab5-private/red.env
IFACE=${LAB_IFACE:-enp0s8}
FILE=/etc/bind/named.conf.options
[[ -f $FILE ]] || { echo "No existe $FILE: BIND no está instalado." >&2; exit 1; }

# DNS IPv4 que el DHCP entregó a este adaptador (como máximo tres).
mapfile -t DHCP_DNS < <(resolvectl dns "$IFACE" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | awk '!v[$0]++' | head -3 || true)
if (( ${#DHCP_DNS[@]} == 0 )); then
  echo "Sin DNS por DHCP en $IFACE: no se cambian los reenviadores de BIND."
  exit 0
fi
# Primero los de la red y después los públicos, sin repetir ninguno.
LIST=''
declare -A VISTO=()
for dns in "${DHCP_DNS[@]}" 8.8.8.8 1.1.1.1; do
  [[ -n ${VISTO[$dns]:-} ]] && continue
  VISTO[$dns]=1
  LIST+="$dns; "
done
LIST=${LIST% }

cp -a "$FILE" "$FILE.bak.$(date +%Y%m%d%H%M%S)"
sed -i -E "s|^([[:space:]]*)forwarders \{[^}]*\};|\1forwarders { ${LIST} };|; s|^([[:space:]]*)dnssec-validation [a-z]+;|\1dnssec-validation no;|" "$FILE"
named-checkconf /etc/bind/named.conf
systemctl restart named
echo "Reenviadores de BIND: ${LIST}   (validación DNSSEC desactivada)"
for prueba in ubuntu.com example.com; do
  respuesta=$(dig +time=5 +tries=1 +short @127.0.0.1 "$prueba" A 2>/dev/null | head -1 || true)
  echo "  $prueba -> ${respuesta:-SIN RESPUESTA (normal si esta red no tiene Internet; la zona del laboratorio no lo necesita)}"
done
