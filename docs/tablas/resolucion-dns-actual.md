# Resolución actual Docker

| FQDN | Tipo | Valor observado | Servicio |
|---|---|---|---|
| ns1.aerolinea.redes.test | A | 172.30.0.53 | dns |
| ldap.aerolinea.redes.test | A | 172.30.0.11 | ldap |
| www.aerolinea.redes.test | A | 172.30.0.12 | web |
| mail.aerolinea.redes.test | A | 172.30.0.13 | mail |
| ftp.aerolinea.redes.test | A | 172.30.0.14 | ftp |
| aerolinea.redes.test | NS | ns1.aerolinea.redes.test. | DNS |
| aerolinea.redes.test | MX | 10 mail.aerolinea.redes.test. | Correo |
| aerolinea.redes.test | SOA | ns1.; admin.; serial 2026100701 | DNS |

Zona validada: integration/dns/db.aerolinea.redes.test; no representa la red física. La tabla histórica se conserva en resolucion-dns.md.
