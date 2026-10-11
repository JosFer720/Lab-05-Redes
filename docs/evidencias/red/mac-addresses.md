# MAC reales

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

Las seis MAC Docker son unicast localmente administradas y distintas; se preservaron los valores generados y se fijaron por el cambio observado al reiniciar. Persistencia demostrada en interfaces-antes-reinicio.json e interfaces-contenedores.json; no equivalen a MAC de VM VirtualBox.
