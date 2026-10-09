# Cliente

Scripts para ejecutar la matriz desde el equipo cliente.

Instalar las herramientas necesarias:

```bash
sudo apt update
sudo apt install -y dnsutils ldap-utils curl swaks
```

Copiar `shared/lab.example.env` como un archivo local terminado en `.env`,
completar las credenciales y cargarlo antes de ejecutar:

```bash
cd client
cp ../shared/lab.example.env ../shared/lab.env
# Editar ../shared/lab.env: IPs actuales y claves reales.
set -a
source ../shared/lab.env
set +a
./tests/test-all.sh | tee resultados.txt
```

El archivo `.env` y los resultados generados no se guardan en Git.

El cliente debe usar ns1 como resolvedor para que LDAP, web, correo y FTP se
alcancen por nombre. Desde la raíz del repositorio se puede preparar con
`sudo DNS_SERVER=<IP-ns1> ./client/scripts/start.sh`. Las opciones de resolución
con y sin `systemd-resolved` se mantienen en ese script.

La prueba DNS compara los registros A con `dns/zones/db.aerolinea.redes.test`.
`ZONE_FILE` permite usar otra zona esperada y `DNS_PORT` otro puerto; el entorno
Docker configura su propia zona de prueba sin modificar la zona del grupo.
