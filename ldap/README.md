# LDAP

OpenLDAP con usuarios `inetOrgPerson` bajo `ou=People`.

El servidor ya está desplegado en Ubuntu en el Mac. Los datos de conexión,
los seis usuarios y los accesos de escritorio están en
[`OpenLDAP en este Mac`](../docs/openldap-en-mac.md). El LDIF exportado está
en [`ldif/usuarios-laboratorio.ldif`](ldif/usuarios-laboratorio.ldif), y las
evidencias reales están en [`docs/evidencias/ldap/`](../docs/evidencias/ldap/).

Copiar `ldif/users.example.tsv` fuera del repositorio, completar una fila por
cuenta y ejecutar en la VM LDAP:

```bash
sudo LDAP_ADMIN_PASSWORD='clave-administrativa' \
  USERS_FILE='/ruta/users.tsv' \
  ./scripts/install.sh

sudo LDAP_TEST_USER='usuario1' \
  LDAP_TEST_PASSWORD='clave-del-usuario' \
  ./scripts/verify-local.sh
```

El archivo usa cinco columnas separadas por tabuladores:

```text
uid    cn    sn    mail    password
```

Si la VM ya tenía una base LDAP de otro dominio, respaldarla y ejecutar una
vez con `RECONFIGURE_LDAP=1`. Sin esa variable el instalador conserva la base
existente.

Para arrancar una instalación existente sin reemplazar sus usuarios:

```bash
sudo ./scripts/start.sh
```

Desde el cliente:

```bash
LDAP_USER='usuario1' LDAP_PASSWORD='clave-del-usuario' \
  ../client/tests/test-ldap.sh
```

Desde otro equipo de la red física, usar `LDAP_PORT=1389` en la prueba
del cliente y configurar en DNS la IP del Mac. Dentro de la red de las VMs
el puerto es 389. Ver la guía para los datos de conexión y el estado del DNS.
