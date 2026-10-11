# Matriz de 33 casos

Auditoría ejecutada el 11 de octubre de 2026 en NERY (America/Los_Angeles). Alcance: integración Docker validada en un host físico. La comunicación con equipos del grupo y Thunderbird no está demostrada.

| ID | Docker / protocolo | LAN física del grupo | Evidencia / límite |
|---|---|---|---|
| DNS-01 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| DNS-02 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| DNS-03 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| DNS-04 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| DNS-05 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| LDAP-01 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| LDAP-02 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| LDAP-03 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| LDAP-04 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| WEB-01 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| WEB-02 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| WEB-03 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| WEB-04 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| WEB-05 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| MAIL-01 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| MAIL-02 | BLOCKED | BLOCKED | matriz-final.json; Thunderbird no disponible |
| MAIL-03 | BLOCKED | BLOCKED | matriz-final.json; Thunderbird no disponible |
| MAIL-06 | BLOCKED | BLOCKED | matriz-final.json; Thunderbird no disponible |
| MAIL-04 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| MAIL-05 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| MAIL-07 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| FTP-01 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| FTP-02 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| FTP-03 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| FTP-04 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| FTP-05 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| FTP-06 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| FTP-07 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| FTP-08 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| INT-01 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| INT-02 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| INT-03 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |
| INT-04 | PASS | BLOCKED | matriz-final.json; ver detalle por ID y fecha |


Resultado local: {'PASS': 30, 'FAIL': 0, 'BLOCKED': 3}. Resultado LAN: 0 PASS, 0 FAIL, 33 BLOCKED; cliente físico no disponible. MAIL-03 y MAIL-06 tienen autenticación/lectura por protocolo complementaria, pero el enunciado exige Thunderbird. WEB-02/03/04 y FTP se verificaron programáticamente; las capturas gráficas finales están pendientes.

Cada ID tiene procedimiento, esperado, observado, máquina, alcance y fecha en evidencias/integration/actual/matriz-final.json. Suite anterior: suite-existente.txt. Reinicio: despues-reinicio.txt y persistencia.txt. Logs: logs-dns/ldap/web/mail/ftp.txt.
