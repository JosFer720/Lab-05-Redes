# Servidor DNS: BIND9

Esta implementación proporciona:

- servidor autoritativo para la zona `aerolinea.redes.test` con los registros SOA, NS, MX
  y A de `ns1`, `ldap`, `www`, `mail` y `ftp`;
- recursión limitada a redes privadas, con reenvío a `8.8.8.8` y `1.1.1.1` para que las
  demás VMs sigan teniendo internet (`apt`) usando este DNS;
- registro de cada consulta en el journal (`journalctl -u named`), que sirve como evidencia;
- instalador repetible, actualización de IPs con un solo comando (sube el serial y valida
  la zona antes de guardar) y pruebas desde el servidor y desde el cliente.

## Despliegue en Ubuntu 24.04

```bash
cd dns
sudo ./scripts/install.sh
sudo ./scripts/verify-local.sh
```

El instalador puede repetirse sin duplicar nada: valida la configuración y la zona del
repositorio antes de tocar `/etc/bind`, respalda los archivos que reemplaza, reinicia `named`
y lo deja habilitado al arranque. No modifica Netplan, el DNS del sistema ni UFW.

Variables opcionales:

```bash
sudo DOMAIN=aerolinea.redes.test NAMED_THREADS=2 ./scripts/install.sh
```

También se aceptan `DNS_IP`, `LDAP_IP`, `WEB_IP`, `MAIL_IP` y `FTP_IP` para actualizar
la zona durante la instalación. `LOCAL_NETWORK=10.223.12.0/24` limita la recursión
a esa red y al propio servidor; sin esa variable se permiten los rangos privados
de la configuración. La zona y la configuración anteriores se respaldan antes
de reemplazarlas.

`NAMED_THREADS` limita los hilos de `named` (y se arranca solo con IPv4). BIND abre un socket
por hilo y por IP, y en un equipo con muchos núcleos la salida de `ss -lntup` (INT-03) se llena
de líneas repetidas.

Si UFW está activo, abrir el puerto de DNS:

```bash
sudo ufw allow 53/udp
sudo ufw allow 53/tcp
```

## IPs de la zona

La zona incluida conserva las IPs de la red del grupo del 7 de octubre de 2026
(`10.223.12.x`). Hay que actualizarlas si el grupo cambia de red. Las IPs `192.0.2.x`
son un rango de documentación y se detectan como pendientes. Cuando cada integrante
confirme la IP de su VM:

```bash
./scripts/set-ips.sh ns1=<IP> ldap=<IP> www=<IP> mail=<IP> ftp=<IP>   # cualquier subconjunto
```

Cada ejecución sube el serial (`AAAAMMDDNN`), valida con `named-checkzone` (si falla no guarda
nada), regenera [`docs/tablas/resolucion-dns.md`](../docs/tablas/resolucion-dns.md) y despliega la
zona reiniciando BIND. Con `DEPLOY=0` solo edita el archivo del repositorio.

El enunciado pide que ns1 use una IP fija o reservada: en una VM se fija con Netplan; en una red
con DHCP (como la del campus) hay que reservarla en el router o usar una red propia del grupo.

## Apuntar las demás máquinas a ns1

Cada VM y el cliente usan la IP de ns1 como único DNS (en la propia VM de ns1, `127.0.0.1`).
Ejemplo en `/etc/netplan/50-cloud-init.yaml`, seguido de `sudo netplan apply`:

```yaml
network:
  version: 2
  ethernets:
    enp0s3:                       # nombre real: ip a
      dhcp4: false
      addresses: [<IP-de-la-VM>/24]
      routes:
        - to: default
          via: <puerta-de-enlace>
      nameservers:
        addresses: [<IP-de-ns1>]
        search: [aerolinea.redes.test]
```

No se resuelve nada con `/etc/hosts`. Si `apt` falla después de cambiar el DNS, ns1 está apagado
o sus `forwarders` están bloqueados en esa red.

## Pruebas

En ns1:

```bash
sudo ./scripts/verify-local.sh
```

Desde la raíz del repositorio en el cliente, cuya resolución DNS debe apuntar a ns1:

```bash
./client/tests/test-dns.sh
DNS_SERVER=<IP-de-ns1> ./client/tests/test-dns.sh     # consultando a ns1 directamente
DNS_SERVER=127.0.0.1 DNS_PORT=15353 ZONE_FILE=integration/dns/db.aerolinea.redes.test ./client/tests/test-dns.sh
```

Pruebas manuales (DNS-01 a DNS-05):

```bash
dig @<IP-de-ns1> ns1.aerolinea.redes.test A
dig @<IP-de-ns1> aerolinea.redes.test SOA      # buscar "aa" en flags: respuesta autoritativa
dig @<IP-de-ns1> aerolinea.redes.test NS
dig @<IP-de-ns1> aerolinea.redes.test MX
dig @<IP-de-ns1> noexiste.aerolinea.redes.test # status: NXDOMAIN
sudo named-checkzone aerolinea.redes.test /etc/bind/zones/db.aerolinea.redes.test
```

## Evidencias

```bash
./scripts/collect-evidence.sh                       # en ns1
DNS_SERVER=<IP-de-ns1> ./scripts/collect-evidence.sh   # desde un cliente
```

Guarda en `docs/evidencias/dns/` la salida completa de cada prueba, un archivo por ID de la matriz
(`DNS-01`, `DNS-02`, `DNS-03`, `DNS-04`, `DNS-05`, `MAIL-01`), la validación de la zona y, solo en
ns1, el estado del servicio, los puertos y los logs (`INT-02`, `INT-03`, `INT-04`). Las capturas de
pantalla las toma una persona; estos archivos acompañan a las capturas.

## Cómo funciona

- `named.conf.options` define cómo se comporta el servidor y `named.conf.local` declara que es
  `master` (autoritativo) de la zona; el archivo de zona contiene los datos.
- Cuando alguien pregunta por un nombre de `aerolinea.redes.test`, BIND responde con la zona y marca
  la respuesta con el flag `aa` (authoritative answer). Un nombre que no existe recibe `NXDOMAIN`.
- El SOA identifica la zona: servidor primario (`ns1`), contacto, el **serial** (que debe subir en
  cada cambio para que otros servidores detecten que la zona cambió) y los tiempos de refresco.
- El MX indica a qué servidor se entrega el correo del dominio (`mail`, prioridad 10).
- Para cualquier otro nombre (por ejemplo `ubuntu.com`) BIND actúa como resolvedor: reenvía la
  consulta a los `forwarders`. Solo atiende a redes privadas para no ser un resolvedor abierto.
- El TTL de la zona es de 300 s para que un cambio de IP se note rápido en las cachés de los clientes.
- `interface-interval 1` hace que BIND detecte en un minuto una IP nueva (cambio de red) y empiece
  a escuchar en ella.

## Nombre del dominio

El enunciado escribe `aerolínea.redes.test` con tilde. Se usa `aerolinea.redes.test`, sin tilde,
porque un nombre DNS con caracteres no ASCII necesita codificación (punycode:
`xn--aerolnea-g2a.redes.test`) y complica BIND, Postfix y Thunderbird. Conviene confirmarlo con el
catedrático; si pide la tilde, solo cambian el nombre de la zona y el archivo `db.*`.

## ns1 sobre WSL2 en Windows

`windows/` contiene los scripts usados cuando ns1 corre en una distro de WSL2 en lugar de una VM
(el servidor y sus pruebas son exactamente los mismos):

- `iniciar-ns1.ps1`: levanta la distro `lab5-ns1`, la mantiene viva y muestra la IP que deben usar
  los compañeros (`-Detener` la apaga). No necesita administrador.
- `lan-on.ps1`: expone ns1 a la red local (modo `mirrored` de WSL y reglas de firewall para el
  puerto 53 solo desde redes privadas). Necesita administrador; con `-DryRun` solo muestra lo que haría.
- `lan-off.ps1`: deshace lo anterior.

En WSL con modo `mirrored`, el puerto 53 puede entrar en conflicto con servicios
de Windows. Verificar desde otra máquina con `dig @<IP-de-ns1>` por UDP y con
`dig +tcp @<IP-de-ns1>`. Para las pruebas dentro de ns1, si `127.0.0.1` no llega a
BIND, usar `sudo DNS_SERVER=<IP-local> ./scripts/verify-local.sh`. Los scripts
de Windows requieren la distro `lab5-ns1`; no la crean automáticamente.
