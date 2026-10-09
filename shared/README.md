# Valores compartidos

La tabla de nombres e IPs se genera desde la zona BIND en
[`docs/tablas/resolucion-dns.md`](../docs/tablas/resolucion-dns.md).

Copiar `lab.example.env` a `lab.env`, actualizar las direcciones para la red
actual del grupo y completar las contraseñas de las cuentas LDAP y FTP.
El ejemplo conserva las IPs documentadas del hotspot del 7 de octubre de 2026.
El archivo `lab.env` queda excluido de Git.

Desde la raíz del repositorio:

```bash
set -a
source shared/lab.env
set +a
./client/tests/test-all.sh
```
