# Preparación del puente para la red del profesor

**Estado actual: configuración puente aplicada; arranque bloqueado por Windows.**
Esta preparación se hizo desde otra red. El usuario confirmó que no hay
otro equipo autorizado disponible y que no puede cerrar FC26 ahora.
Los 33 PASS del reporte anterior corresponden al despliegue host-only;
no demuestran acceso desde la LAN del profesor.

| Dato | Resultado observado |
|---|---|
| VM con los seis servicios nativos | CC3067-Lab5-Ubuntu |
| GNS3 VM | Otra VM, sin modificar |
| Estado actual de Ubuntu | Apagada, tras apagado seguro por SSH |
| Adaptador 1 | Bridged, Realtek PCIe GbE Family Controller, cable conectado |
| MAC principal conservada | **08:00:27:5c:08:8e** |
| Adaptador 2 conservado | Host-only, MAC 08:00:27:b1:41:d6 |
| Windows Ethernet | 192.168.1.22/24, MAC 04:bf:1b:bc:3f:77 |
| Wi-Fi | VirtualBox indica Down; no se seleccionó |
| IPv4 anterior de Ubuntu | NAT 10.0.2.15/24; host-only 192.168.56.10/24 |
| IPv4 actual en puente | **No obtenida ni verificada: Ubuntu no arrancó** |
| Funcionamiento del puente | Pendiente de DHCP y tráfico real |
| Servicios accesibles desde LAN | **No comprobados; actualmente la VM está apagada** |

Antes del cambio se verificaron por SSH las seis unidades reales activas:
named, slapd, apache2, postfix@-, dovecot y vsftpd. Se ejecutaron `ip link show`,
`ip -4 addr`, `ip route` y `hostname -I`; la ruta anterior era NAT vía 10.0.2.2.
El apagado se solicitó con `sudo systemctl poweroff`; se esperó `VMState=poweroff`
antes de cambiar el adaptador. Se respaldó el archivo .vbox antes del apagado
y después del apagado en `.git/virtualbox-private/puente-backup/`.
No se regeneró ninguna MAC ni se descartaron estados guardados.

## Bloqueo observado

VirtualBox falló al encender Ubuntu con:

```text
Call to WHvSetupPartition failed: E_ACCESSDENIED
(Last=0xc0000022/5) (VERR_NEM_VM_CREATE_FAILED)
```

El mismo error se reprodujo con NAT en una prueba controlada, y se restauró
el puente sobre Realtek después. El driver VirtualBox NDIS6 de Ethernet está
habilitado. También falló el arranque solicitado mediante el shell de Windows.
Esto ocurre antes de arrancar Linux: todavía no permite diagnosticar DHCP.

Windows tenía FC26 abierto y poca memoria libre. Su relación causal con el
error **no está confirmada**. No se cerró el juego, no se modificó Hyper-V,
no se deshabilitó la seguridad y no se reinició Windows. El usuario indicó
que no puede cerrar FC26 ahora; cuando pueda, se debe reintentar y observar
si el error cambia. Si persiste, conservar el log y diagnosticar Windows antes
de modificar DHCP o afirmar que la red rechaza la VM.

Evidencias: [vbox-antes.txt](evidencias/puente/vbox-antes.txt),
[vbox-despues.txt](evidencias/puente/vbox-despues.txt),
[windows-adaptadores.txt](evidencias/puente/windows-adaptadores.txt),
[estado.json](evidencias/puente/estado.json) y
[arranque-fallido.txt](evidencias/puente/arranque-fallido.txt).

## Configuración al llegar a la red del profesor

Mantener adaptador 1 en **Bridged Adapter**, MAC **08:00:27:5c:08:8e**, cable
conectado y DHCP en Ubuntu (`enp0s3`). Seleccionar la interfaz física que
realmente conecte Windows a esa red. Conservar el adaptador 2 host-only como
acceso administrativo; no usar sus direcciones como registros DNS para los
clientes externos. No fijar la IP NAT anterior ni la IP de la red doméstica.

Con Ubuntu apagado, seleccionar Ethernet o Wi-Fi:

```powershell
powershell -ExecutionPolicy Bypass -File virtualbox/preparar-puente.ps1 -InterfaceAlias Ethernet
# Si la conexión real en clase es Wi-Fi, usar -InterfaceAlias 'Wi-Fi'.
powershell -ExecutionPolicy Bypass -File virtualbox/iniciar-vm.ps1
```

El selector exige una interfaz física conectada y una VM apagada, respalda
.vbox y comprueba que la MAC se conserve. Si la VM está guardada, restaurar
normalmente su estado y apagar Ubuntu; no descartar el estado.

Después de arrancar, entrar por host-only:

```powershell
python virtualbox/ssh-run.py --command 'ip link show; ip -4 addr; ip route; hostname -I'
powershell -ExecutionPolicy Bypass -File virtualbox/aplicar-lan.ps1
```

`aplicar-lan.ps1` está preparado, con sintaxis verificada, **pero no se pudo
ejecutar ni validar en Ubuntu durante esta preparación**. Lee la IPv4 real
de enp0s3 y su prefijo; rechaza la dirección NAT. Respalda las configuraciones,
actualiza los A de la zona e incrementa el serial, añade el segmento real a
la ACL DNS, ajusta FTP pasivo y limita los puertos a ese segmento mediante
UFW. Conserva host-only y no amplía mynetworks de Postfix. Para una red con
direcciones públicas se requiere revisar el alcance manualmente.

Luego verificar desde Windows y desde otro equipo autorizado, consultando
explícitamente el DNS en la IPv4 real de Ubuntu: A/MX, LDAP 389, HTTP 80,
SMTP 25/587, IMAP 143 y FTP 21 con transferencia pasiva. Usar los FQDN
`ns1`, `ldap`, `www`, `mail` y `ftp.aerolinea.redes.test`. Comprobar ambos
sentidos con ping o una conexión autorizada. Si DHCP falla, revisar enlace,
lease/journal de systemd-networkd, DHCP del profesor, filtrado MAC y aislamiento
de clientes, sin asignar una IP que no haya sido autorizada.

## MAC que debe conocer el profesor

La MAC de la interfaz virtual principal es **08:00:27:5c:08:8e**. En Ethernet,
hay que contrastarla con la tabla ARP/DHCP del profesor cuando se conecte;
esa observación externa no se realizó aquí. La MAC física Ethernet de Windows
es **04:bf:1b:bc:3f:77**.

Sobre Wi-Fi, VirtualBox sustituye la MAC origen de las tramas salientes por
la MAC de la tarjeta inalámbrica anfitriona; no se debe garantizar que el
punto de acceso verá la MAC virtual. La MAC Wi-Fi inspeccionada es
**4c:49:6c:38:14:ea**. Informar al profesor de ambas si se usará Wi-Fi y pedirle
que confirme el criterio de registro y la observación ARP/DHCP. Véase el
[manual oficial de Oracle](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/networkingdetails.html).
