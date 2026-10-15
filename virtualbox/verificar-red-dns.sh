#!/usr/bin/env bash
# Comprueba, desde esta VM, que ns1 está listo para que otros equipos lo usen como DNS y que la zona apunta a
# servicios alcanzables. No cambia nada.
#   1. Esta VM: IP en la red, BIND escuchando en UDP y TCP 53 sobre esa IP, UFW y ACL de recursión con esa red,
#      zona válida con ns1 = esta IP, respuestas autoritativas por UDP y por TCP, NXDOMAIN y salida a Internet.
#   2. La zona: a dónde apunta ldap, www, mail y ftp (esta VM u otro equipo) y si cada puerto responde.
# Uso, dentro de la VM:  sudo bash /opt/lab5/virtualbox/verificar-red-dns.sh
#   desde Windows:       powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 verificar
# Termina con código 0 si no hay [FAIL]. Si algo falla por un cambio de red: sudo bash .../cambiar-ip.sh
set -uo pipefail
[[ $EUID == 0 ]] || { echo 'Ejecute con sudo' >&2; exit 1; }
[[ -f /root/lab5-private/red.env ]] && source /root/lab5-private/red.env
IFACE=${LAB_IFACE:-enp0s8}
DOMAIN=aerolinea.redes.test
ZONE=/etc/bind/zones/db.$DOMAIN
failed=0
warned=0
ok()   { printf '[PASS] %s\n' "$1"; }
bad()  { printf '[FAIL] %s\n' "$1"; failed=$((failed + 1)); }
warn() { printf '[WARN] %s\n' "$1"; warned=$((warned + 1)); }
esc()  { printf '%s' "$1" | sed 's/\./\\./g'; }
zone_ip() { awk -v n="$1" '$1 == n && $2 == "IN" && $3 == "A" {print $4; exit}' "$ZONE"; }
in_net() { python3 -c 'import ipaddress,sys; sys.exit(0 if ipaddress.ip_address(sys.argv[1]) in ipaddress.ip_network(sys.argv[2]) else 1)' "$1" "$2" 2>/dev/null; }
# La red de una regla o de la ACL vale si es la de la VM o una más ancha que la contiene.
cubre() { python3 -c 'import ipaddress,sys; sys.exit(0 if ipaddress.ip_network(sys.argv[1]).subnet_of(ipaddress.ip_network(sys.argv[2], strict=False)) else 1)' "$1" "$2" 2>/dev/null; }
# Búsquedas sin salida anticipada de grep (evita falsos fallos por SIGPIPE con pipefail).
tiene() { grep -E "$1" >/dev/null; }

echo "=== 1. Esta VM como servidor DNS ==="
CIDR=$(ip -4 -o addr show dev "$IFACE" scope global 2>/dev/null | awk 'NR==1 {print $4}')
if [[ -z $CIDR ]]; then
  bad "El adaptador $IFACE no tiene IPv4: ¿Wi-Fi desconectado o DHCP sin respuesta? Revise el adaptador en puente de la VM."
  exit 1
fi
IP=${CIDR%/*}
NET=$(python3 -c 'import ipaddress,sys; print(ipaddress.ip_interface(sys.argv[1]).network)' "$CIDR")
ok "Adaptador en puente $IFACE: $IP (red $NET)   <- esta es la IP que los demás ponen como DNS"

systemctl is-active --quiet named && ok "named está activo" || bad "named no está activo (sudo systemctl restart named)"
systemctl is-enabled --quiet named && ok "named arranca solo con la VM" || bad "named no está habilitado al arranque"

ss -lunH 2>/dev/null | tiene "(^|[[:space:]])$(esc "$IP"):53([[:space:]]|\$)" \
  && ok "BIND escucha en UDP $IP:53" || bad "BIND no escucha en UDP $IP:53 (sudo systemctl restart named; si persiste, revise journalctl -u named)"
ss -ltnH 2>/dev/null | tiene "(^|[[:space:]])$(esc "$IP"):53([[:space:]]|\$)" \
  && ok "BIND escucha en TCP $IP:53" || bad "BIND no escucha en TCP $IP:53"

UFW=$(ufw status 2>/dev/null || true)
if tiene '^Status: active' <<<"$UFW"; then
  for proto in udp tcp; do
    red_regla=$(awk -v p="53/$proto" -v i="$IFACE" '$1 == p && $2 == "on" && $3 == i && $4 ~ /^ALLOW/ && !hecho {print $5; hecho = 1}' <<<"$UFW")
    if [[ -n $red_regla ]] && cubre "$NET" "$red_regla"; then ok "UFW admite 53/$proto en $IFACE desde $red_regla (cubre tu red $NET)"
    else bad "UFW no admite 53/$proto para tu red $NET (regla actual: ${red_regla:-ninguna}); las reglas son de otra red: sudo bash /opt/lab5/virtualbox/cambiar-ip.sh"; fi
  done
else
  warn "UFW está inactivo: el puerto 53 no está filtrado (no impide la conexión, pero la VM queda sin firewall)"
fi

ACL_NET=$(grep -m1 'acl "red-lab"' /etc/bind/named.conf.options 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+' | head -1 || true)
if [[ -n $ACL_NET ]] && cubre "$NET" "$ACL_NET"; then ok "La recursión de BIND (ACL red-lab: $ACL_NET) cubre tu red $NET"
else bad "La ACL de recursión es '${ACL_NET:-vacía}' y tu red es $NET: los equipos de esta red no podrían resolver nombres de Internet (cambiar-ip.sh)"; fi

named-checkzone "$DOMAIN" "$ZONE" >/dev/null 2>&1 && ok "named-checkzone sin errores (serial $(awk '/;[[:space:]]*serial/ {print $1; exit}' "$ZONE"))" || bad "named-checkzone falla"
NS1=$(zone_ip ns1)
if [[ $NS1 == "$IP" ]]; then ok "La zona dice ns1 = $IP (la IP real de la VM)"
else bad "La zona dice ns1 = ${NS1:-nada} pero la VM tiene $IP: los demás consultarían una IP vieja (sudo bash /opt/lab5/virtualbox/cambiar-ip.sh)"; fi

DIGO=(+time=3 +tries=1)
dig "${DIGO[@]}" +norecurse "@$IP" "$DOMAIN" SOA 2>/dev/null | tiene 'flags:[^;]* aa[ ;]' \
  && ok "Respuesta autoritativa (flag aa) por UDP en $IP:53" || bad "Sin respuesta autoritativa por UDP en $IP:53"
dig "${DIGO[@]}" +tcp +norecurse "@$IP" "$DOMAIN" SOA 2>/dev/null | tiene 'flags:[^;]* aa[ ;]' \
  && ok "Respuesta autoritativa (flag aa) por TCP en $IP:53" || bad "Sin respuesta por TCP en $IP:53"
dig "${DIGO[@]}" "@$IP" "noexiste.$DOMAIN" A 2>/dev/null | tiene 'status: NXDOMAIN' \
  && ok "Un nombre inexistente da NXDOMAIN" || bad "Un nombre inexistente no da NXDOMAIN"
externo=$(dig "${DIGO[@]}" +short -b "$IP" "@$IP" ubuntu.com A 2>/dev/null | head -1 || true)
FORWARDERS=$(grep -m1 forwarders /etc/bind/named.conf.options | sed -E 's/^ *forwarders \{ *//; s/ *\};//')
if [[ -n $externo ]]; then
  ok "Resuelve nombres de Internet para su red (reenviadores: $FORWARDERS)"
else
  # ¿Hay Internet en esta red? Si ningún reenviador contesta nada, no es un error de BIND: la red no tiene salida.
  hay_internet=0
  for f in $(grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' <<<"$FORWARDERS"); do
    if [[ -n $(dig "${DIGO[@]}" +short "@$f" ubuntu.com A 2>/dev/null | head -1 || true) ]]; then hay_internet=1; break; fi
  done
  if (( hay_internet )); then
    bad "Los reenviadores ($FORWARDERS) responden pero BIND no resuelve Internet: quien use esta VM como DNS general se quedaría sin navegar (sudo bash /opt/lab5/virtualbox/ajustar-dns-salida.sh)"
  else
    warn "Esta red no tiene salida a Internet (ningún reenviador responde): es normal en un laboratorio aislado. Los nombres de la zona no dependen de Internet y funcionan igual"
  fi
fi

echo
echo "=== 2. A dónde apunta la zona y si responde ==="
declare -A PUERTOS=([ldap]="389" [www]="80" [mail]="25 587 143" [ftp]="21")
declare -A NOMBRE=([ldap]="LDAP" [www]="web" [mail]="correo" [ftp]="FTP")
for n in ldap www mail ftp; do
  addr=$(zone_ip "$n")
  if [[ -z $addr ]]; then bad "$n.$DOMAIN no tiene registro A en la zona"; continue; fi
  if [[ $addr == "$IP" ]]; then
    donde="esta VM"
  else
    donde="otro equipo"
    if ! in_net "$addr" "$NET"; then
      warn "$n -> $addr no pertenece a tu red $NET: desde las demás computadoras esa IP no se alcanza. Pide a quien aloja ${NOMBRE[$n]} la IP que tiene en ESTA red (la IP privada de una VM tras NAT, como 192.168.50.x de Lima, no sirve)"
    fi
  fi
  resultado=''
  alcanzable=1
  for p in ${PUERTOS[$n]}; do
    if timeout 3 bash -c "exec 3<>/dev/tcp/$addr/$p" 2>/dev/null; then resultado+=" $p:abierto"
    else resultado+=" $p:CERRADO"; alcanzable=0; fi
  done
  if (( alcanzable )); then ok "$n.$DOMAIN -> $addr ($donde): ${NOMBRE[$n]} responde en${resultado}"
  else
    pista='¿IP equivocada, servicio apagado, VM sin red en puente o firewall cerrado?'
    if [[ $n == ldap && $resultado == *389:CERRADO* ]] && timeout 3 bash -c "exec 3<>/dev/tcp/$addr/1389" 2>/dev/null; then
      pista='Ese equipo sí tiene el 1389 abierto: LDAP está publicado en el 1389 (reenvío de Lima) y el DNS no puede indicar puertos; debe publicarlo en el 389'
    fi
    bad "$n.$DOMAIN -> $addr ($donde): ${NOMBRE[$n]} no responde en${resultado}. $pista"
  fi
done

echo
if (( failed == 0 )); then
  echo "RESULTADO: todo listo. Los demás equipos deben usar $IP como DNS (avisos: $warned)."
else
  echo "RESULTADO: $failed comprobaciones fallan (avisos: $warned). Corrija en el orden en que aparecen; lo de la sección 1 impide que los demás usen este DNS."
fi
exit $(( failed > 0 ))
