# Tabla de resolución de nombres DNS

Zona autoritativa aerolinea.redes.test, servida por BIND9 en ns1. Serial 2026100702, TTL 300 s.
Generada por dns/scripts/gen-table.sh a partir de dns/zones/db.aerolinea.redes.test.

| Nombre | Tipo | Valor | TTL (s) | Servicio |
|---|---|---|---|---|
| aerolinea.redes.test. | SOA | ns1.aerolinea.redes.test. admin.aerolinea.redes.test. (serial 2026100702) | 300 | Autoridad de la zona |
| aerolinea.redes.test. | NS | ns1.aerolinea.redes.test. | 300 | Servidor de nombres |
| aerolinea.redes.test. | MX | 10 mail.aerolinea.redes.test. | 300 | Correo (prioridad 10) |
| ns1.aerolinea.redes.test. | A | 10.223.12.73 | 300 | BIND9 |
| ldap.aerolinea.redes.test. | A | 10.223.12.169 | 300 | OpenLDAP |
| www.aerolinea.redes.test. | A | 10.223.12.11 | 300 | Apache |
| mail.aerolinea.redes.test. | A | 10.223.12.202 | 300 | Postfix + Dovecot |
| ftp.aerolinea.redes.test. | A | 10.223.12.123 | 300 | vsftpd |
