# Laboratorio 5: Servicios de capa 7

Repositorio de configuración y evidencias para `aerolinea.redes.test`.

## Estructura

```text
.
├── dns/                 # BIND9 y zona DNS
├── ldap/                # OpenLDAP y usuarios LDIF
├── web/                 # Apache y autenticación LDAP
├── mail/                # Postfix y Dovecot
├── ftp/                 # Implementación de vsftpd
├── client/              # Pruebas ejecutadas desde el cliente
├── docs/                # Reporte, diagramas, tablas y evidencias
└── shared/              # Valores compartidos y plantillas
```

## OpenLDAP

La instalación de OpenLDAP en Ubuntu, los seis usuarios del laboratorio y las
pruebas están en [`ldap/README.md`](ldap/README.md). La guía
[`OpenLDAP en Ubuntu sobre Mac`](docs/openldap-en-mac.md) documenta las VMs,
los puertos, la integración con el DNS del grupo y las evidencias reales.

## Web

La implementación de Apache con login LDAP está en [`web/README.md`](web/README.md).
El sitio se compila con `npm run build` en `web/site` y luego se despliega en la
VM web:

```bash
cd web
sudo ./scripts/install.sh
sudo ./scripts/verify-local.sh
```

Desde el cliente:

```bash
WEB_USER='usuario' WEB_PASSWORD='clave-ldap' ./client/tests/test-web.sh
```

## FTP

La implementación lista para desplegar está en [`ftp/README.md`](ftp/README.md).
Debe ejecutarse en la VM Ubuntu destinada exclusivamente a FTP. No modifica
Netplan, DNS ni UFW automáticamente.

```bash
cd ftp
sudo FTP_PASSWORD='Lab5-ftp' ./scripts/install.sh
sudo ./scripts/verify-local.sh
```

Desde el cliente, cuya resolución DNS debe apuntar a `ns1`:

```bash
FTP_PASSWORD='Lab5-ftp' ./client/tests/test-ftp.sh
```
