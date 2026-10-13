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

## Cliente Windows (o Mac/Linux) contra un servidor en la red

Cuando los servicios corren en la VM de otra computadora (modo puente), el cliente no necesita `dig`
ni `ldap-utils`: `windows/cliente.ps1` comprueba red y puertos, crea una regla DNS solo para
`*.aerolinea.redes.test` (sin tocar `hosts` ni el DNS general) y ejecuta la matriz con Python
(`virtualbox/pruebas-windows.py`, que también corre en Mac/Linux):

```powershell
powershell -ExecutionPolicy Bypass -File client/windows/cliente.ps1 estado  -Servidor <IP>
powershell -ExecutionPolicy Bypass -File client/windows/cliente.ps1 dns-on  -Servidor <IP>   # administrador
powershell -ExecutionPolicy Bypass -File client/windows/cliente.ps1 pruebas -Servidor <IP> -Credenciales C:\ruta\credentials.json
powershell -ExecutionPolicy Bypass -File client/windows/cliente.ps1 ldap    -Servidor <IP> -Credenciales C:\ruta\credentials.json
powershell -ExecutionPolicy Bypass -File client/windows/cliente.ps1 dns-off                  # administrador
```

En Mac/Linux: `LAB_DNS_SERVER=<IP> LAB_CREDENTIALS=~/credentials.json python3 virtualbox/pruebas-windows.py`.
Variables: `LAB_DNS_SERVER`, `LAB_CREDENTIALS`, `LAB_RESULTS`, `LAB_EXPECTED_IP`, `LAB_ZONE_FILE`
(descritas en la cabecera del script). Quien aloja el servidor genera `credentials.json` con
`virtualbox/generar-credenciales.py` y se lo entrega a los clientes por un canal privado.

La prueba DNS compara los registros A con `dns/zones/db.aerolinea.redes.test`.
`ZONE_FILE` permite usar otra zona esperada y `DNS_PORT` otro puerto; el entorno
Docker configura su propia zona de prueba sin modificar la zona del grupo.
