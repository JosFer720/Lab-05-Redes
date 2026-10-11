# Direccionamiento observado

Auditoría ejecutada el 11 de octubre de 2026 en NERY (America/Los_Angeles). Alcance: integración Docker validada en un host físico. La comunicación con equipos del grupo y Thunderbird no está demostrada.

| Equipo/servicio | IPv4 | MAC | Gateway | DNS / puertos |
|---|---|---|---|---|
| Windows Ethernet | 192.168.1.22/24 (DHCP) | 04:bf:1b:bc:3f:77 | 192.168.1.1 | DNS de ISP; ver dns-cliente.txt |
| VirtualBox host-only | 192.168.56.1/24 | 0a:00:27:00:00:11 | Ninguno | DHCP .101-.254 |
| Ubuntu WSL2 | 172.30.209.167/20 | 00:15:5d:d2:c8:70 | 172.30.208.1 | 10.255.255.254 |
| Docker dns | 172.30.0.53/24 | 7a:81:bc:6b:49:6d | 172.30.0.1 | 53 TCP/UDP |
| Docker ldap | 172.30.0.11/24 | da:be:92:8d:ec:a3 | 172.30.0.1 | 389 TCP |
| Docker web | 172.30.0.12/24 | d2:6f:38:29:ab:b7 | 172.30.0.1 | 80 TCP |
| Docker mail | 172.30.0.13/24 | ae:80:58:42:27:14 | 172.30.0.1 | 25/587/143 TCP |
| Docker ftp | 172.30.0.14/24 | 5e:58:f7:76:6f:26 | 172.30.0.1 | 21 + 40000-40100 TCP |
| Docker client | 172.30.0.20/24 | ae:a8:01:58:34:8c | 172.30.0.1 | cliente |

Las MAC de GNS3 son 08:00:27:4e:6f:23 (host-only) y 08:00:27:41:e0:7c (NAT). IP del invitado no comprobada: VM en estado saved. No se cambia la MAC de ninguna VM. La IP Ethernet doméstica no tiene reserva DHCP verificada. Las IP Docker son fijas por IPAM.
