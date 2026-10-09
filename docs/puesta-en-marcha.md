# Puesta en marcha

## Orden

1. Asignar una dirección fija a cada VM.
2. Desplegar DNS y hacer que todas las VMs lo usen como resolvedor.
3. Desplegar LDAP y cargar al menos dos cuentas.
4. Compilar y desplegar Apache.
5. Desplegar Postfix y Dovecot.
6. Desplegar vsftpd.
7. Ejecutar verificaciones locales en cada VM.
8. Ejecutar la suite integrada desde el cliente.

## Dependencias

| Servicio | Debe alcanzar |
|---|---|
| DNS | Ningún servicio interno |
| LDAP | DNS para el resto de la red |
| Apache | DNS y LDAP |
| Postfix y Dovecot | DNS y LDAP |
| FTP | DNS para ser localizado por el cliente |
| Cliente | DNS, Apache, correo y FTP |

## Puertos

| Servicio | Puertos TCP | Puertos UDP |
|---|---|---|
| DNS | 53 | 53 |
| LDAP | 389 | Ninguno |
| Web | 80 | Ninguno |
| Correo | 25, 587, 143 | Ninguno |
| FTP | 21, 40000 a 40100 | Ninguno |

Los instaladores no cambian UFW. Si está activo, abrir solamente los puertos
de la VM correspondiente.

## Prueba completa

En el cliente:

```bash
cp shared/lab.example.env shared/lab.env
```

Editar `shared/lab.env` y luego ejecutar:

```bash
set -a
source shared/lab.env
set +a
./client/tests/test-all.sh | tee resultados.txt
```

Las pruebas que requieren interfaz gráfica se completan en el navegador y en
el cliente de correo. Los logs se obtienen con:

```bash
sudo journalctl -u named -u slapd --since today
sudo tail -n 100 /var/log/apache2/aerolinea-error.log
sudo journalctl -u postfix -u dovecot --since today
sudo tail -n 100 /var/log/vsftpd.log
```
