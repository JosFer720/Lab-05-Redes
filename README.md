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
