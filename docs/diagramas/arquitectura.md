# Arquitectura de servicios

```mermaid
flowchart LR
    C[Cliente]
    DNS[BIND9 DNS]
    LDAP[OpenLDAP]
    WEB[Apache]
    MAIL[Postfix y Dovecot]
    FTP[vsftpd]

    C -->|Consultas DNS| DNS
    C -->|HTTP puerto 80| WEB
    C -->|SMTP puerto 587| MAIL
    C -->|IMAP puerto 143| MAIL
    C -->|FTP puerto 21| FTP
    WEB -->|Autenticación puerto 389| LDAP
    MAIL -->|Autenticación y cuentas puerto 389| LDAP
    WEB -.->|Resuelve ldap por DNS| DNS
    MAIL -.->|Resuelve ldap por DNS| DNS
```

## Responsabilidades

| Componente | Se conecta con | Propósito |
|---|---|---|
| Cliente | DNS | Resolver nombres del dominio |
| Cliente | Apache | Abrir el sitio y probar el acceso protegido |
| Cliente | Correo | Enviar por SMTP y leer por IMAP |
| Cliente | FTP | Listar, cargar y descargar archivos |
| Apache | LDAP | Validar usuario y contraseña |
| Postfix | LDAP | Comprobar que el destinatario existe |
| Dovecot | LDAP | Autenticar el acceso al buzón |
| FTP | Usuario local | Autenticar sin depender de LDAP |

Todas las conexiones entre servicios utilizan nombres DNS. No se requieren
entradas manuales en el archivo `hosts`.
