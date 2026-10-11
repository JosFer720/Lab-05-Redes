# Matriz VirtualBox — 33 casos

2026-10-11T21:38:55.979016+00:00: {'PASS': 33}. Windows independiente y servidor Ubuntu VirtualBox, mismo equipo físico.

| Caso | Estado | Observado |
|---|---|---|
| DNS-01 | PASS | 192.168.56.10 |
| DNS-02 | PASS | {'ldap': '192.168.56.10', 'www': '192.168.56.10', 'mail': '192.168.56.10', 'ftp': '192.168.56.10'} |
| DNS-03 | PASS | status: NOERROR; flags: qr aa ra; id 3616 opcode QUERY rcode NOERROR flags QR AA RA ;QUESTION aerolinea.redes.test. IN SOA ;ANSWER aerolinea.redes.test. 300 IN SOA ns1.aerolinea.redes.test. admin.aerolinea.redes.test. 2026101101 3600 900 604800 300 ; |
| DNS-04 | PASS | 10 mail.aerolinea.redes.test. |
| DNS-05 | PASS | status: NXDOMAIN; flags: qr aa rd ra; id 38956 opcode QUERY rcode NXDOMAIN flags QR AA RD RA ;QUESTION noexiste.aerolinea.redes.test. IN A ;ANSWER ;AUTHORITY aerolinea.redes.test. 300 IN SOA ns1.aerolinea.redes.test. admin.aerolinea.redes.test. 20261 |
| LDAP-01 | PASS | dn: uid=fruiz,ou=People,dc=aerolinea,dc=redes,dc=test uid: fruiz cn: Fernando Ruiz sn: Ruiz mail: fruiz@aerolinea.redes.test  dn: uid=hbarillas,ou=People,dc=aerolinea,dc=redes,dc=test uid: hbarillas cn: Hugo Barillas sn: Barillas mail: hbarillas@aero |
| LDAP-02 | PASS | Seis binds válidos |
| LDAP-03 | PASS | Siete rechazos LDAP 49 |
| LDAP-04 | PASS | dn: uid=fruiz,ou=People,dc=aerolinea,dc=redes,dc=test uid: fruiz cn: Fernando Ruiz sn: Ruiz mail: fruiz@aerolinea.redes.test  dn: uid=hbarillas,ou=People,dc=aerolinea,dc=redes,dc=test uid: hbarillas cn: Hugo Barillas sn: Barillas mail: hbarillas@aero |
| WEB-01 | PASS | 192.168.56.10 |
| WEB-02 | PASS | HTTP 200; Aerolínea Redes |
| WEB-03 | PASS | Seis logins y logout correctos |
| WEB-04 | PASS | Ambos accesos rechazados |
| WEB-05 | PASS | HTTP 500 durante caída LDAP; login recuperado tras systemctl start; ver WEB-05.txt |
| MAIL-01 | PASS | ('192.168.56.10', '10 mail.aerolinea.redes.test.') |
| MAIL-02 | PASS | [{'uid': 'jvalladares', 'host': 'mail.aerolinea.redes.test', 'port': 143, 'auth': 3, 'socket': 0}, {'uid': 'nmolina', 'host': 'mail.aerolinea.redes.test', 'port': 143, 'auth': 3, 'socket': 0}] |
| MAIL-03 | PASS | [{'uid': 'nmolina', 'status': 0, 'folders': [{'name': 'INBOX', 'uri': 'imap://nmolina@mail.aerolinea.redes.test/INBOX'}, {'name': 'Trash', 'uri': 'imap://nmolina@mail.aerolinea.redes.test/Trash'}]}, {'uid': 'jvalladares', 'status': 0, 'folders': [{'n |
| MAIL-06 | PASS | {'smtp': {'status': 0, 'error': None}, 'recibido': {'subject': 'VirtualBox-Thunderbird-1791754710719388300', 'from': 'nmolina@aerolinea.redes.test', 'to': 'jvalladares@aerolinea.redes.test', 'uri': 'imap-message://jvalladares@mail.aerolinea.redes.tes |
| MAIL-04 | PASS | IMAP AUTHENTICATIONFAILED; reproducción gráfica pendiente |
| MAIL-05 | PASS | SMTP entregado e IMAP FETCH verificado: Lab5-audit-1791753894409937400 |
| MAIL-07 | PASS | 550 5.1.1 <noexiste@aerolinea.redes.test>: Recipient address rejected: User unknown in virtual mailbox table |
| FTP-01 | PASS | 192.168.56.10 |
| FTP-02 | PASS | 220 (vsFTPd 3.0.5) |
| FTP-03 | PASS | 530 Login incorrect. |
| FTP-04 | PASS | 530 Permission denied. |
| FTP-05 | PASS | ['bienvenida.txt', 'uploads'] |
| FTP-06 | PASS | 226 Transfer complete. |
| FTP-07 | PASS | SHA256 337f064e85bbe39232f1594e5b358063eed4fb6904d6e85f2ae0618f155cc888 |
| FTP-08 | PASS | CWD .. permanece /; 550 Failed to open file. |
| INT-01 | PASS | # Copyright (c) 1993-2009 Microsoft Corp. # # This is a sample HOSTS file used by Microsoft TCP/IP for Windows. # # This file contains the mappings of IP addresses to host names. Each # entry should be kept on an individual line. The IP address shoul |
| INT-02 | PASS | Boot ID distinto; seis servicios activos; IP/MAC conservadas; contenido Maildir/FTP conserva SHA256. Ver antes/despues-reinicio.txt |
| INT-03 | PASS | 53 TCP/UDP, 389,80,25,587,143,21; procesos nativos /system.slice, VirtualBox oracle. Ver INT-03.txt |
| INT-04 | PASS | Logs de bind LDAP, HTTP, SMTP/LMTP, IMAP, carga y descarga FTP; ver logs-nativos.txt |

Procedimientos completos y evidencias: [matriz-final.json](evidencias/virtualbox/matriz-final.json). Las pruebas LAN entre computadoras físicas quedan pendientes.
