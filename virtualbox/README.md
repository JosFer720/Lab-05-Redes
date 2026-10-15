# Laboratorio nativo en Oracle VirtualBox

La VM de trabajo es `CC3067-Lab5-Ubuntu`, Ubuntu 24.04 x86_64.
Los servicios se instalan con `apt` y arrancan con `systemd` dentro de la VM.
Las evidencias de esta ejecución están en `docs/evidencias/virtualbox/`.
Consulte la [matriz nueva](../docs/matriz-pruebas-virtualbox.md) para conocer
los resultados efectivamente ejecutados.

## Encender mañana

Desde PowerShell, en `C:\Users\josem\Downloads\Lab-05-Redes`:

```powershell
powershell -ExecutionPolicy Bypass -File virtualbox/iniciar-vm.ps1
powershell -ExecutionPolicy Bypass -File virtualbox/estado-vm.ps1
```

El script espera SSH y seis unidades activas. Las seis unidades están configuradas para
arrancar automáticamente. Compruebe la red y entre por SSH:

```powershell
powershell -ExecutionPolicy Bypass -File virtualbox/verificar-red.ps1
powershell -ExecutionPolicy Bypass -File virtualbox/conectar-ssh.ps1
```

Dentro de Ubuntu:

```bash
sudo bash /opt/lab5/virtualbox/arrancar-servicios.sh
sudo bash /opt/lab5/virtualbox/verificar-servicios.sh
```

También puede ejecutar un comando directamente desde Windows:

```powershell
python virtualbox/ssh-run.py --command 'systemctl is-active named slapd apache2 postfix dovecot vsftpd'
ssh -i .git/virtualbox-private/id_rsa.openssh -o UserKnownHostsFile=.git/virtualbox-private/known_hosts labadmin@192.168.56.10
```

## Clientes Windows

```powershell
powershell -ExecutionPolicy Bypass -File virtualbox/iniciar-cliente.ps1
powershell -ExecutionPolicy Bypass -File virtualbox/abrir-web.ps1
```

Thunderbird utiliza un perfil exclusivo del laboratorio con `nmolina` y
`jvalladares`. IMAP: `mail.aerolinea.redes.test:143`; SMTP Submission: mismo
nombre, puerto 587, contraseña normal y autenticación LDAP. Los protocolos
del servidor se configuran sin TLS dentro de la red privada del laboratorio.
El cliente gráfico utiliza un túnel SSH cifrado por SOCKS en loopback
`127.0.0.1:10805`, que resuelve los FQDN dentro de Ubuntu. Solo admite los
puertos de correo y el sitio del laboratorio. No afecta perfiles personales
ni la DNS global de Windows.

El sitio original se abre en un perfil separado de Edge por ese mismo túnel.
Para consultas DNS directas desde Windows:

```powershell
Resolve-DnsName www.aerolinea.redes.test -Server 192.168.56.10
Resolve-DnsName aerolinea.redes.test -Server 192.168.56.10 -Type MX
```

Las pruebas programáticas de Windows consultan BIND por DNS real y resuelven
los nombres solo en su propio proceso. Las credenciales renovadas están
en `.git/lab5-private/credentials.json`; las claves SSH y perfiles, en
`.git/virtualbox-private/`. Estos archivos no se versionan ni se imprimen
en las evidencias. Conserve esas carpetas privadas para reproducir la sesión.

## Pruebas reproducibles

Requisitos de Python Windows: `paramiko`, `pycdlib`, `dnspython`, `ldap3`,
`marionette-driver`, `playwright`, `reportlab` y `pypdf`.

```powershell
python virtualbox/pruebas-windows.py
python virtualbox/validar-thunderbird.py
python virtualbox/validar-integracion.py
python docs/reporte/generar-reporte-virtualbox.py
```

`validar-integracion.py` detiene/restaura temporalmente `slapd` y reinicia
realmente Ubuntu. Ejecútelo cuando pueda interrumpir una demostración.
Requiere resultados previos de las pruebas Windows y Thunderbird.
Las pruebas locales del servidor se ejecutan por SSH:

```powershell
python virtualbox/ssh-run.py --command 'sudo bash /opt/lab5/virtualbox/ejecutar-pruebas.sh'
```

La matriz local de protocolos deja los casos que exigen Thunderbird pendientes;
la matriz combinada incorpora únicamente los resultados de la aplicación real.
La prueba entre computadoras físicas del grupo sigue requiriendo otro equipo:
host-only solo conecta esta computadora con sus VMs.

## Red y operación

| Adaptador | IPv4 | MAC | Uso |
|---|---|---|---|
| enp0s3 / NAT | 10.0.2.15/24 | 08:00:27:5c:08:8e | Paquetes, gateway 10.0.2.2 |
| enp0s8 / host-only | 192.168.56.10/24 | 08:00:27:b1:41:d6 | Servicios hacia Windows |
| Windows host-only | 192.168.56.1/24 | 0a:00:27:00:00:11 | Cliente independiente |

Todos los registros A del laboratorio apuntan a `192.168.56.10`. La zona
efectiva está en `/etc/bind/zones/db.aerolinea.redes.test` y se conserva como
evidencia. Los puertos son DNS 53 TCP/UDP, LDAP 389, HTTP 80, SMTP 25/587,
IMAP 143 y FTP 21 con pasivo 40000–40100. UFW restringe aplicaciones a
host-only; NAT publica únicamente SSH en `127.0.0.1:22225`.

Para apagar normalmente:

```powershell
powershell -ExecutionPolicy Bypass -File virtualbox/detener-vm.ps1
```

`detener-servicios.sh` detiene las unidades sin deshabilitarlas. No descarta
estados guardados ni borra discos. GNS3 VM permanece separada y guardada.

## Crear y desplegar otra vez

En esta computadora la VM ya está registrada. `crear-ubuntu.py` conserva una
VM existente y no la recrea. Para una instalación nueva descarga la imagen
oficial seleccionada, verifica SHA256, crea disco dinámico de 25 GiB y semilla
NoCloud con clave SSH. Usa BIOS, 1 CPU, 1536 MB, HPET y adaptadores virtio;
esta configuración se seleccionó tras diagnosticar bloqueos de arranque.
GRUB aplica `quiet noapic clocksource=acpi_pm` para evitar el fallo de
temporizador encontrado en el reinicio. El intento fallido se conserva
en las evidencias; INT-02 registra la comprobación definitiva.

```powershell
python virtualbox/crear-ubuntu.py
python virtualbox/desplegar.py
```

`desplegar.py` transfiere fuentes y archivos privados por SFTP a `/opt/lab5`
y `/root/lab5-private`, y ejecuta `instalar-servicios.sh`. El instalador usa
los scripts nativos existentes de DNS, LDAP, web, correo y FTP; compila React
con Node nativo; respalda configuraciones y habilita las unidades. Los archivos
privados se generan con finales LF. La configuración opcional del índice de
sugerencias de comandos de apt se respalda en `/var/backups/lab5/` para evitar
regenerarla durante cada instalación. No aloja servicios en WSL o contenedores.

El snapshot `Ubuntu-inicial-SSH` conserva el sistema antes de instalar los
servicios. Los discos de los intentos anteriores de arranque permanecen
conservados fuera de Git. `main` y el repositorio remoto se mantienen intactos.
El snapshot `Lab5-servicios-persistentes` conserva los servicios instalados
con la VM apagada. Un intento de snapshot en vivo no terminó y fue cancelado;
el snapshot sin memoria de ejecución se guardó correctamente.

## Modo puente (otros equipos de la red)

Host-only solo conecta a esta computadora con la VM. Para que otros equipos del
grupo alcancen los cinco servicios, la VM se crea con un segundo adaptador en
puente a la tarjeta física (Wi-Fi o Ethernet) y obtiene su IP por DHCP. El
adaptador NAT se conserva para instalar paquetes y para administrar por SSH
(`127.0.0.1:22225`). Los valores originales no cambian si no se definen estas
variables:

```powershell
# Si el repositorio está en una carpeta sincronizada (OneDrive), guarde los secretos fuera de ella.
# Las credenciales deben estar en <LAB5_PRIVATE_DIR>\lab5-private\credentials.json.
$env:LAB5_PRIVATE_DIR = "$env:USERPROFILE\.lab5-private"
$env:LAB_NET_MODE = 'bridged'          # crear-ubuntu.py: NAT + puente (LAB_BRIDGE_ADAPTER opcional)
python virtualbox/crear-ubuntu.py

$env:LAB_SSH_HOST = '127.0.0.1'; $env:LAB_SSH_PORT = '22225'   # administración por NAT
# IP y red que la VM recibió por DHCP en enp0s8 (ip -br addr):
$env:LAB_IP = '192.168.1.50'; $env:LAB_NETWORK = '192.168.1.0/24'
$env:LAB_IFACE = 'enp0s8'; $env:LAB_RESOLVER = '127.0.0.1'
$env:LAB_PORTS = '53 80 389 25 587 143 21'   # sin SSH hacia la red local
python virtualbox/desplegar.py
```

Como la IP viene por DHCP, conviene reservarla en el router usando la MAC del
adaptador en puente (`VBoxManage showvminfo CC3067-Lab5-Ubuntu --machinereadable`,
campo `macaddress2`). En Wi-Fi, VirtualBox sustituye la MAC de origen por la de la
tarjeta del equipo físico en las tramas que salen al aire; la MAC de la VM solo
viaja dentro de los paquetes DHCP, que es lo que un router usa para reservar la IP.

Dos problemas de VirtualBox 7.2 con Hyper-V/WSL2 activos que `crear-ubuntu.py` ya
resuelve: `--x2apic off` dejaba el APIC principal apagado (`Cannot disable the APIC
for a 64-bit guest`; ahora se activa `--apic on`) y, en algunos equipos, el kernel
entraba en pánico en el primer arranque con `IO-APIC + timer doesn't work!` antes de
que cloud-init pudiera corregir GRUB. Como la VM usa una sola CPU, el IO-APIC se
apaga por defecto; `LAB_IOAPIC=on` restaura el comportamiento original.

Si la red o la IP cambian (otro Wi-Fi, hotspot), dentro de la VM:

```bash
sudo bash /opt/lab5/virtualbox/cambiar-ip.sh
```

Actualiza la zona DNS, la red permitida de BIND, la dirección pasiva de FTP y UFW.
Después hay que avisar a los demás equipos de la nueva IP del DNS.

### Todo en un comando y utilidades

| Archivo | Para qué |
|---|---|
| `levantar-puente.ps1` | Primera vez en una PC Windows: comprueba requisitos, genera credenciales, crea la VM en puente, espera el arranque, lee la IP por DHCP, instala los cinco servicios y muestra IP y MAC. `-Adaptador "<nombre>"` elige el adaptador físico; `-Forzar` reinstala. |
| `puente.ps1 iniciar\|estado\|ip\|mac\|verificar\|ips\|entregables\|respaldar\|importar\|kit\|ssh\|traer\|detener` | Operación diaria de la VM en puente; todo funciona sin Internet. `verificar` comprueba el puerto 53 UDP/TCP, UFW, ACL, zona y los servicios de la zona; `ips ldap=IP www=IP mail=IP ftp=IP` carga las IPs de los compañeros (`nombre=vm` o `--todo-en-la-vm` las devuelve a esta VM, `--simular` solo muestra); `entregables [carpeta]` reúne zona, tablas, evidencias DNS e informe del verificador; `respaldar` apaga la VM y la exporta a un `.ova` con SHA256; `importar <ova>` la restaura (mismas MAC, puente al adaptador activo de esa PC, reenvío SSH según `LAB_NAT_SSH_PORT`); `kit [carpeta] [--con-ova]` junta guías, paquete, llaves, credenciales y paquetes de Python (`wheels\`) para un USB. `traer <ruta-en-la-VM> [destino]` copia archivos o carpetas de la VM a Windows (scp). `LAB_VM_NAME` y `LAB_NAT_SSH_PORT` permiten una segunda VM. |
| `verificar-red-dns.sh`, `entregables-dns.sh` | Dentro de la VM: el verificador de ns1 (lo ejecuta `puente.ps1 verificar`) y el que reúne los entregables de DNS (`puente.ps1 entregables`). Sin Internet, la salida a Internet da `[WARN]`, no `[FAIL]`. |
| `red-auto.sh`, `instalar-red-auto.sh` | Vigilante `lab5-red-auto` (temporizador de systemd, cada minuto): si cambia la IP o la red del adaptador en puente, ejecuta `cambiar-ip.sh`. `instalar-servicios.sh` lo instala. Ver lo que hizo: `sudo journalctl -u lab5-red-auto --since today`. |
| `generar-users-tsv.py` | Convierte `credentials.json` en el `users.tsv` que pide `ldap/scripts/install.sh`, para cargar los mismos seis usuarios y claves en el LDAP de otro equipo (el archivo contiene claves). |
| `generar-credenciales.py` | Crea `credentials.json` con claves aleatorias (no las imprime). Lo entrega, por un canal privado, quien aloja el servidor a quien lo prueba. |
| `esperar-vm.py` | Espera SSH, cloud-init y la IP de `enp0s8`; imprime `LAB_IP`, `LAB_NETWORK`. |
| `instalar-en-ubuntu.sh` | Alternativa sin Windows ni VirtualBox: dentro de cualquier Ubuntu 24.04 con red en puente (VM de UTM, VMware, Parallels... x86-64 o ARM64), `sudo bash virtualbox/instalar-en-ubuntu.sh` genera las credenciales y deja los cinco servicios funcionando. `--solo-preparar` solo calcula IP y archivos. |
| `crear-paquete.py` | Zip sin secretos para pasar estos scripts a otro equipo antes de subirlos al repositorio. Incluye el sitio web ya compilado (`web/site/dist`, si existe) para instalar Apache sin Node ni Internet, y normaliza los saltos de línea a LF. |
| `ajustar-dns-salida.sh` | Hace que BIND resuelva Internet en la red actual: reenvía primero a los DNS que entrega el DHCP del adaptador en puente (los hotspots y muchas redes bloquean `1.1.1.1` o DNSSEC hacia DNS públicos) y desactiva `dnssec-validation`. No hace nada si no hay DNS por DHCP. Lo ejecutan `cambiar-ip.sh` e `instalar-servicios.sh`. |
| `cambiar-ip.sh` | Reconfigura zona, BIND, FTP pasivo y UFW al cambiar la IP o la red (lee `/root/lab5-private/red.env`). Acepta `IP/prefijo` y, si los demás servicios corren en computadoras de los compañeros, `ldap=IP www=IP mail=IP ftp=IP` (ns1 sigue siendo esta VM). Lo no indicado conserva su valor si su IP es de la red actual; si era de otra red (otro Wi-Fi) o apuntaba a esta VM, el nombre pasa a la IP actual de la VM, que tiene los cinco servicios. `nombre=vm` y `--todo-en-la-vm` devuelven nombres a la VM; `--simular` muestra la zona resultante sin cambiar nada. |

La batería oficial desde otra computadora (cliente) se explica en [`client/README.md`](../client/README.md).
