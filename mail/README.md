# Correo

Postfix y Dovecot con buzones Maildir y autenticación LDAP.

La implementación habilita SMTP en los puertos 25 y 587, IMAP en el puerto
143 y entrega local mediante LMTP. Las cuentas se validan contra OpenLDAP.

## Instalación en Ubuntu

La VM de correo debe estar conectada a la red del laboratorio y utilizar como
resolvedor el servidor DNS autoritativo del grupo. Antes de instalar, comprobar
que DNS resuelve el servidor LDAP y que el puerto 389 está disponible:

```bash
getent hosts ldap.aerolinea.redes.test
nc -vz ldap.aerolinea.redes.test 389
```

Ejecutar en la VM de correo cuando DNS y LDAP ya respondan:

```bash
sudo ./scripts/install.sh
```

El instalador no modifica la red de la VM ni las reglas de firewall. Si UFW
está activo, permitir los puertos del servicio:

```bash
sudo ufw allow 25/tcp
sudo ufw allow 143/tcp
sudo ufw allow 587/tcp
```

Verificar la configuración y la autenticación con una cuenta LDAP:

```bash
sudo MAIL_TEST_USER='usuario1' \
  MAIL_TEST_PASSWORD='clave-del-usuario' \
  ./scripts/verify-local.sh
```

Desde el cliente se necesitan `dig`, `curl` y `swaks`:

```bash
MAIL_USER='usuario1' \
MAIL_PASSWORD='clave-del-usuario' \
MAIL_RECIPIENT='usuario2@aerolinea.redes.test' \
MAIL_RECIPIENT_USER='usuario2' \
MAIL_RECIPIENT_PASSWORD='clave-del-destinatario' \
  ../client/tests/test-mail.sh
```

Los logs relacionados con las pruebas se consultan con:

```bash
sudo journalctl -u postfix -u dovecot --since today
```

Configuración del cliente de correo:

- IMAP en `mail.aerolinea.redes.test`, puerto 143, sin cifrado
- SMTP en `mail.aerolinea.redes.test`, puerto 587, sin cifrado
- autenticación con contraseña normal
- nombre de usuario igual al `uid` LDAP

Esta configuración sin TLS solo debe usarse en la red aislada del laboratorio.
