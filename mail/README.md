# Correo

Postfix y Dovecot con buzones Maildir y autenticación LDAP.

La implementación habilita SMTP en los puertos 25 y 587, IMAP en el puerto
143 y entrega local mediante LMTP. Las cuentas se validan contra OpenLDAP.

## Docker (forma recomendada para este equipo)

Docker Desktop publica el servidor de correo en la computadora anfitriona.
Copiar el archivo de ejemplo y ajustar las IPs únicamente si el equipo de DNS
o LDAP usa valores distintos de los del plan:

```powershell
Copy-Item .env.example .env
notepad .env
docker compose up --build -d
docker compose ps
```

El estado debe ser `healthy` y los puertos `25`, `143` y `587` deben aparecer
publicados. Para revisar el servicio:

```powershell
docker compose logs -f
```

El DNS del laboratorio debe apuntar `mail.aerolinea.redes.test` a la dirección
IPv4 de la computadora que ejecuta Docker, no a una IP interna del contenedor.
Esa IP se ve con `ipconfig`. Si el cliente está en otra máquina, permitir en
el firewall de Windows los puertos TCP 25, 143 y 587.

Cuando LDAP esté disponible, desde el cliente se ejecuta la prueba integrada:

```bash
MAIL_USER='usuario1' \
MAIL_PASSWORD='clave-del-usuario1' \
MAIL_RECIPIENT='usuario2@aerolinea.redes.test' \
MAIL_RECIPIENT_USER='usuario2' \
MAIL_RECIPIENT_PASSWORD='clave-del-usuario2' \
  ./client/tests/test-mail.sh
```

Para apagar el servicio sin borrar los correos:

```powershell
docker compose down
```

Los buzones permanecen en el volumen Docker `mail_mail_data`.

## Instalación directa en VM

Ejecutar en la VM de correo cuando DNS y LDAP ya respondan:

```bash
sudo ./scripts/install.sh
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

Configuración del cliente de correo:

- IMAP en `mail.aerolinea.redes.test`, puerto 143, sin cifrado
- SMTP en `mail.aerolinea.redes.test`, puerto 587, sin cifrado
- autenticación con contraseña normal
- nombre de usuario igual al `uid` LDAP

Esta configuración sin TLS solo debe usarse en la red aislada del laboratorio.
