# Servidor FTP: vsftpd

Esta implementación proporciona:

- acceso local limitado a `ftpuser`;
- acceso anónimo deshabilitado;
- jaula `chroot` en `/srv/ftp/ftpuser`;
- raíz de la jaula no escribible y cargas en `uploads/`;
- modo pasivo limitado a los puertos TCP 40000 a 40100;
- log detallado en `/var/log/vsftpd.log`.

## Despliegue en Ubuntu 24.04

```bash
sudo FTP_PASSWORD='Lab5-ftp' ./scripts/install.sh
```

La contraseña es obligatoria y se recibe por ambiente para que no quede
guardada dentro del script. El instalador puede repetirse sin duplicar entradas,
respalda la configuración anterior y valida la nueva antes de reiniciar.

Variables opcionales:

```bash
sudo FTP_USER=ftpuser \
  FTP_PASSWORD='Lab5-ftp' \
  FTP_ROOT=/srv/ftp/ftpuser \
  PASV_MIN_PORT=40000 \
  PASV_MAX_PORT=40100 \
  ./scripts/install.sh
```

Si la VM está detrás de NAT, se puede definir `PASV_ADDRESS` con la IP o nombre
que realmente utiliza el cliente. En una LAN puenteada normalmente se omite.

El script no toca UFW. Si ya está activo, abrir explícitamente:

```bash
sudo ufw allow 21/tcp
sudo ufw allow 40000:40100/tcp
```

Después del despliegue:

```bash
sudo ./scripts/verify-local.sh
FTP_PASSWORD='Lab5-ftp' ../client/tests/test-ftp.sh
```

## Control y datos

El puerto 21 mantiene la conexión de control (`USER`, `PASS`, `LIST`, `RETR`,
`STOR`, `QUIT`). En modo pasivo, cada listado o transferencia abre otra
conexión a un puerto de 40000 a 40100 y la cierra al finalizar. FTP transmite
credenciales y datos sin cifrado; esta configuración es solo para la red
aislada del laboratorio.

## Ejecución local en macOS

Con Docker y OrbStack activos:

```bash
cd ftp
PASV_ADDRESS='IP-DE-LA-COMPUTADORA' \
FTP_PASSWORD='Lab5-ftp' \
docker compose up -d --build
```

El servidor queda disponible en el puerto 21 de la computadora. Los datos usan
el puerto 40000. `PASV_ADDRESS` debe ser la dirección que utilizarán los
demás equipos de la red.

Prueba local:

```bash
curl --user 'ftpuser:Lab5-ftp' ftp://127.0.0.1/
```

Para detenerlo:

```bash
docker compose down
```
