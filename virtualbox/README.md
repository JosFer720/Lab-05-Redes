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
