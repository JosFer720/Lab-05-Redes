# Auditoría actual

Auditoría ejecutada el 11 de octubre de 2026 en NERY (America/Los_Angeles). Alcance: integración Docker validada en un host físico. La comunicación con equipos del grupo y Thunderbird no está demostrada.

## Fuentes y prioridades

Se leyó el PDF oficial `C:/Users/josem/Downloads/CC3067 - Laboratorio 5 - 2026.pdf` (6 páginas), el PDF AeroQuetzal (16 páginas renderizadas) y su PPTX (16 diapositivas, texto y tablas). El enunciado exige 33 casos, 100 puntos y entrega el 8 de octubre de 2026. Esta auditoría es posterior a esa fecha. AeroQuetzal es una propuesta de nube independiente, sin despliegue autorizado.

Repositorio principal inspeccionado recursivamente: DNS, LDAP, web, correo, FTP, cliente, integración, scripts y evidencias. Se conservó la implementación del equipo. `main` local estaba en 2503560; `origin/main` en da6c3a7. Rama de trabajo: `auditoria/lab5-20261011`, creada desde origin/main. Sin modificaciones a main ni publicación remota. No se encontró AGENTS.md en el repositorio.

La versión reciente había eliminado mail/docker, mail/Dockerfile y mail/compose.yaml mediante e81b1c8; el archivo activo del IDE era de la versión antigua. Se conserva la implementación de correo vigente en integration/mail; no se restauran carpetas eliminadas por el equipo.

## Equipo realmente observado

Windows 11 Home x64, compilación 26300; el campo WindowsProductName heredado dice Windows 10, mientras Win32_OperatingSystem y OsName confirman Windows 11. Intel Core i7-13650HX: 14 núcleos, 20 hilos. RAM visible ~15.7 GiB; memoria disponible fluctuó entre 0.5 y 1 GiB. Disco C con ~656 GiB libres. HyperVisorPresent=True y WSL2 funciona; las propiedades VT-x=False no prueban ausencia de virtualización cuando ya existe un hipervisor. La consulta DISM de funciones opcionales requiere elevación y quedó BLOCKED. No se desactivó ninguna función.

VirtualBox 7.2.14 r174565: solo GNS3 VM, estado saved, 1 CPU, 2048 MB, disco VDI existente, NIC 1 host-only y NIC 2 NAT. No es una VM disponible para reutilización segura del laboratorio. No se encendió ni cambió su estado. Docker Desktop 4.92.0/Engine 29.8.0 estaba detenido; se inició y se construyeron las seis imágenes Ubuntu 24.04 y Node 24.

Ubuntu-24.04 WSL2 no tenía activos named, slapd, apache2, postfix, dovecot ni vsftpd. IP observada 172.30.209.167/20, gateway 172.30.208.1, DNS proxy 10.255.255.254. Esta distro se inspeccionó; los servicios se implementaron en Docker.

Windows Ethernet: 192.168.1.22/24, gateway y DHCP 192.168.1.1; Wi-Fi desconectado. Host-only VirtualBox: 192.168.56.1/24, DHCP VirtualBox .101-.254. WSL: 172.30.208.0/20. Docker: 172.30.0.0/24. No hay solapamiento entre los dos rangos 172.30 observados. No se observaron adaptadores VPN activos en el inventario; no se demuestra ausencia de toda VPN.

## Hallazgos y efecto

- La suite del 9 de octubre documenta 39 comprobaciones Docker; las evidencias LDAP previas son de Lima/macOS y BIND de WSL. No certifican la red actual 192.168.1.0/24.
- La primera suite de hoy reprodujo error `bash\r` en WEB/MAIL: archivos antiguos conservaban CRLF pese a .gitattributes. Se normalizaron a LF todos los archivos correspondientes.
- El fixture LDAP tenía solo usuario1/usuario2. Se añadieron seis integrantes desde el LDIF del equipo sin borrar el directorio. Se generaron claves nuevas para las seis cuentas, administrador local y FTP. Los dos usuarios de fixture siguen presentes, aislados; sus claves públicas no deben usarse en la LAN.
- Las contraseñas publicadas de los seis integrantes y el administrador del Mac están comprometidas. Se retiraron de la guía; se requiere rotación coordinada en el equipo remoto. Su historial Git y hashes históricos siguen expuestos; no se reescribió la historia ni se alteró el servidor del compañero.
- El instalador FTP anterior creaba siete cuentas con claves predeterminadas, incluido guest; README decía ftpuser. Ahora exige credenciales explícitas y describe ambas modalidades. No elimina usuarios existentes.
- La integración no declaraba volúmenes Maildir/LDAP/FTP ni reinicio automático. Se añadieron; se verificaron reinicios y conservación de archivos previos.
- Apache podía agotar el tiempo de espera al detener LDAP. Se acotaron LDAPConnectionTimeout, LDAPTimeout y LDAPRetries; WEB-05 obtuvo HTTP 500 y log real, seguido de logins válidos tras recuperar LDAP.
- Docker regeneraba MAC al reiniciar. Se fijaron las MAC válidas y únicas observadas en esta red aislada. La VM GNS3 no se modificó.
- Postfix no entregaba logs de entrega a docker logs con stdout después de daemonizar. Ahora escribe /var/log/postfix.log; se registra status=sent, LMTP y rechazo 550. Dovecot y slapd registran operaciones. Los mensajes se verifican por contenido único, evitando PASS por mensajes antiguos.
- Los rechazos FTP/MAIL anteriores podían aceptar cualquier error de conexión como éxito. Ahora se exigen códigos de autenticación/protocolo específicos y límites de tiempo.
- LDAP remoto Lima usa 1389 publicado, mientras Apache y correo asumían 389. Los instaladores web/mail ahora aceptan LDAP_HOST/LDAP_PORT con validación. No se ha probado ese reenvío desde otra computadora.
- La zona dns/zones y shared/lab.example.env mantienen 10.223.12.x como valores históricos. No se desplegaron sobre la LAN actual; integration/dns es la zona realmente validada.
- DNS del host sigue siendo el de su red doméstica. No se cambiaron Windows DNS, firewall, router, Hyper-V, WSL networkingMode ni reservas DHCP.

## Resultado

30 PASS, 0 FAIL, 3 BLOCKED en la matriz local de protocolos. Los PASS de navegador/cliente FTP son pruebas HTTP/FTP ejecutadas; capturas gráficas académicas pendientes. MAIL-02/03/06 permanecen BLOCKED por Thunderbird según el procedimiento exacto del PDF. Todos los 33 casos en computadoras físicas del grupo están BLOCKED para esta auditoría, por falta de un cliente remoto confirmado y topología compartida accesible.

Evidencia primaria: docs/evidencias/red y docs/evidencias/integration/actual. Los JSON contienen máquina, fecha UTC, alcance, procedimiento, expectativa y observado por caso. Los archivos históricos conservan sus fechas y procedencia; no se reclasifican como ejecuciones actuales.

## Referencias técnicas

- Apache: https://httpd.apache.org/docs/2.4/mod/mod_ldap.html
- Apache form y sesiones: https://httpd.apache.org/docs/2.4/mod/mod_auth_form.html
- Código y documentación de paquetes efectivamente construidos y validaciones named-checkconf, named-checkzone, apache2ctl, postfix check y doveconf.
