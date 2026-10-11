#!/usr/bin/env python3
"""Genera entregables a partir de resultados reales. pip install reportlab"""
from pathlib import Path
import datetime as dt
import json
from xml.sax.saxutils import escape
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.enums import TA_CENTER
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle,PageBreak,Preformatted
from reportlab.graphics.shapes import Drawing,Rect,String,Line

ROOT=Path(__file__).resolve().parents[2]
DOCS=ROOT/'docs'
EV=DOCS/'evidencias/integration/actual'
rows=json.loads((EV/'matriz-final.json').read_text(encoding='utf8'))
nets=json.loads((EV/'interfaces-contenedores.json').read_text(encoding='utf8'))
totals={s:sum(r['status']==s for r in rows) for s in ['PASS','FAIL','BLOCKED']}
def write(name,text): (DOCS/name).write_text(text.strip()+'\n',encoding='utf8')
intro='Auditoría ejecutada el 11 de octubre de 2026 en NERY (America/Los_Angeles). Alcance: integración Docker validada en un host físico. La comunicación con equipos del grupo y Thunderbird no está demostrada.'
audit=f'''# Auditoría actual

{intro}

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
- La primera suite de hoy reprodujo error `bash\\r` en WEB/MAIL: archivos antiguos conservaban CRLF pese a .gitattributes. Se normalizaron a LF todos los archivos correspondientes.
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

{totals['PASS']} PASS, {totals['FAIL']} FAIL, {totals['BLOCKED']} BLOCKED en la matriz local de protocolos. Los PASS de navegador/cliente FTP son pruebas HTTP/FTP ejecutadas; capturas gráficas académicas pendientes. MAIL-02/03/06 permanecen BLOCKED por Thunderbird según el procedimiento exacto del PDF. Todos los 33 casos en computadoras físicas del grupo están BLOCKED para esta auditoría, por falta de un cliente remoto confirmado y topología compartida accesible.

Evidencia primaria: docs/evidencias/red y docs/evidencias/integration/actual. Los JSON contienen máquina, fecha UTC, alcance, procedimiento, expectativa y observado por caso. Los archivos históricos conservan sus fechas y procedencia; no se reclasifican como ejecuciones actuales.

## Referencias técnicas

- Apache: https://httpd.apache.org/docs/2.4/mod/mod_ldap.html
- Apache form y sesiones: https://httpd.apache.org/docs/2.4/mod/mod_auth_form.html
- Código y documentación de paquetes efectivamente construidos y validaciones named-checkconf, named-checkzone, apache2ctl, postfix check y doveconf.
'''
write('auditoria-actual.md',audit)
table='| Equipo/servicio | IPv4 | MAC | Gateway | DNS / puertos |\n|---|---|---|---|---|\n'
table+='| Windows Ethernet | 192.168.1.22/24 (DHCP) | 04:bf:1b:bc:3f:77 | 192.168.1.1 | DNS de ISP; ver dns-cliente.txt |\n'
table+='| VirtualBox host-only | 192.168.56.1/24 | 0a:00:27:00:00:11 | Ninguno | DHCP .101-.254 |\n'
table+='| Ubuntu WSL2 | 172.30.209.167/20 | 00:15:5d:d2:c8:70 | 172.30.208.1 | 10.255.255.254 |\n'
for s,net in nets.items():
    n=next(iter(net.values()))
    ports={'dns':'53 TCP/UDP','ldap':'389 TCP','web':'80 TCP','mail':'25/587/143 TCP','ftp':'21 + 40000-40100 TCP','client':'cliente'}[s]
    table+=f'| Docker {s} | {n["IPAddress"]}/{n["IPPrefixLen"]} | {n["MacAddress"]} | {n["Gateway"]} | {ports} |\n'
write('tabla-direccionamiento.md','# Direccionamiento observado\n\n'+intro+'\n\n'+table+'\nLas MAC de GNS3 son 08:00:27:4e:6f:23 (host-only) y 08:00:27:41:e0:7c (NAT). IP del invitado no comprobada: VM en estado saved. No se cambia la MAC de ninguna VM. La IP Ethernet doméstica no tiene reserva DHCP verificada. Las IP Docker son fijas por IPAM.\n')
write('evidencias/red/mac-addresses.md','# MAC reales\n\n'+table+'\nLas seis MAC Docker son unicast localmente administradas y distintas; se preservaron los valores generados y se fijaron por el cambio observado al reiniciar. Persistencia demostrada en interfaces-antes-reinicio.json e interfaces-contenedores.json; no equivalen a MAC de VM VirtualBox.\n')
write('evidencias/red/direccionamiento.md','# Redes\n\nVer ../../tabla-direccionamiento.md y ../../arquitectura-final.md. Red física actual 192.168.1.0/24, host-only 192.168.56.0/24, WSL 172.30.208.0/20, Docker 172.30.0.0/24. No se verificó rango DHCP del router ni se reservó IP. DNS académico físico queda pendiente.\n')
write('evidencias/red/reinicio-red.txt','Fecha: 2026-10-11, NERY\nPASS: reinicio de servicios Docker, IP/MAC estables; ver ../integration/actual/interfaces-antes-reinicio.json y interfaces-contenedores.json.\nBLOCKED: reinicio de Windows, router, VM GNS3 o computadores físicos no efectuado; no necesario para la integración aislada. WSL MAC estable después de su propio reinicio no comprobada.\n')
architecture='''# Arquitectura realmente implementada

Se eligió estrategia C (Docker/WSL2). La VM GNS3 no aporta una ventaja y tiene estado de otro proyecto; crear Ubuntu con 3-4 GiB comprometería la RAM disponible. No se crearon ni modificaron VMs, no se descargó ISO y no se habilitó bridge.

```mermaid
flowchart TD
    Router[Router doméstico 192.168.1.1 / DHCP] --- Host[NERY Windows 11 / Ethernet 192.168.1.22]
    Host --- Engine[Docker Desktop sobre WSL2]
    Host --- WSL[Ubuntu-24.04 WSL2 172.30.209.167 / inspección]
    Host --- GNS[GNS3 VM saved / host-only + NAT / preservada]
    Engine --- Bridge[Bridge Docker 172.30.0.0/24 / gateway .1]
    Bridge --- Client[Cliente .20 / DNS Docker reenvía a .53]
    Bridge --- DNS[BIND9 .53 / 53 TCP UDP]
    Bridge --- LDAP[OpenLDAP .11 / 389]
    Bridge --- Web[Apache + React .12 / 80]
    Bridge --- Mail[Postfix + Dovecot .13 / 25 587 143]
    Bridge --- FTP[vsftpd .14 / 21 y pasivo 40000-40100]
    Client --> DNS
    Client --> LDAP
    Client --> Web
    Client --> Mail
    Client --> FTP
    Web --> LDAP
    Mail --> LDAP
    Other[Computadoras del grupo / IP y ruta no confirmadas]
```

Other no está conectado al diagrama funcional: la ruta hacia el montaje aislado está pendiente. No se demostró un switch del grupo; el router doméstico se infiere del gateway/DHCP observado. Tabla de MAC/IP: tabla-direccionamiento.md.

Los FQDN se resuelven por BIND con zona integration/dns/db.aerolinea.redes.test. El cliente usa el resolvedor interno de Docker 127.0.0.11, que reenvía al DNS .53. No hay entradas del dominio en /etc/hosts. La versión ASCII aerolinea.redes.test mantiene el acuerdo del equipo; el PDF escribe aerolínea.redes.test con tilde. Se requiere validación académica de esta diferencia.

Publicaciones al host: 127.0.0.1:15353 TCP/UDP -> DNS 53, :1389 -> LDAP 389, :8080 -> Apache 80, :2525 -> SMTP 25, :1587 -> submission 587, :1143 -> IMAP 143. FTP solo interno. No se pueden utilizar estas IP Docker como si fueran direcciones LAN de las computadoras.

DNS no requiere LDAP; Apache y correo requieren DNS y LDAP; FTP depende de DNS para su localización. Los volúmenes LDAP data/config, Maildir y FTP sobreviven a recreación. restart:unless-stopped permite recuperación al arrancar Docker; inicio automático de Docker después de reinicio completo de Windows no fue probado.

## Reutilización para AeroQuetzal

BIND/zona, usuarios inetOrgPerson, autenticación Apache, Maildir, control FTP y matriz automatizada son reutilizables con adaptación. La propuesta tiene dos VM Hetzner, ocho zonas VLSM, edge-vpn/core-app, VPN WireGuard, nftables, CoreDNS, DHCP dnsmasq, NTP chrony, Nginx/Astro y LDAP replicado con LDAPS. Requiere nombres/IP propios, TLS, ACL por rol, rotación de secretos, backups externos, monitorización, pruebas de aislamiento y réplicas. FTP/correo sin TLS y el fixture académico no son apropiados para Internet. No se desplegó nada en Hetzner ni se generaron cargos.
'''
write('arquitectura-final.md',architecture)
dns_table='| FQDN | Tipo | Valor observado | Servicio |\n|---|---|---|---|\n'
for s,host in [('dns','ns1'),('ldap','ldap'),('web','www'),('mail','mail'),('ftp','ftp')]:
    dns_table+=f'| {host}.aerolinea.redes.test | A | {next(iter(nets[s].values()))["IPAddress"]} | {s} |\n'
dns_table+='| aerolinea.redes.test | NS | ns1.aerolinea.redes.test. | DNS |\n| aerolinea.redes.test | MX | 10 mail.aerolinea.redes.test. | Correo |\n| aerolinea.redes.test | SOA | ns1.; admin.; serial 2026100701 | DNS |\n'
write('tablas/resolucion-dns-actual.md','# Resolución actual Docker\n\n'+dns_table+'\nZona validada: integration/dns/db.aerolinea.redes.test; no representa la red física. La tabla histórica se conserva en resolucion-dns.md.\n')
matrix='| ID | Docker / protocolo | LAN física del grupo | Evidencia / límite |\n|---|---|---|---|\n'
for r in rows:
    note='matriz-final.json; '+('Thunderbird no disponible' if r['status']=='BLOCKED' else 'ver detalle por ID y fecha')
    matrix+=f'| {r["id"]} | {r["status"]} | BLOCKED | {note} |\n'
write('matriz-pruebas-final.md',f'# Matriz de 33 casos\n\n{intro}\n\n{matrix}\n\nResultado local: {totals}. Resultado LAN: 0 PASS, 0 FAIL, 33 BLOCKED; cliente físico no disponible. MAIL-03 y MAIL-06 tienen autenticación/lectura por protocolo complementaria, pero el enunciado exige Thunderbird. WEB-02/03/04 y FTP se verificaron programáticamente; las capturas gráficas finales están pendientes.\n\nCada ID tiene procedimiento, esperado, observado, máquina, alcance y fecha en evidencias/integration/actual/matriz-final.json. Suite anterior: suite-existente.txt. Reinicio: despues-reinicio.txt y persistencia.txt. Logs: logs-dns/ldap/web/mail/ftp.txt.\n')
write('cambios-realizados.md','''# Cambios realizados

Se respaldó el repositorio antes de cambios en .git/lab5-backups/antes-auditoria.tar; las configuraciones y hashes LDAP previos se respaldan en .git/lab5-private/ldap-before-*.ldif. Son archivos privados fuera del índice Git. Los servicios no existían en este proyecto Docker antes del despliegue.

- LF en archivos heredados; se mantienen .gitattributes y contenido del sitio React.
- Volúmenes/restart/puertos localhost y MAC preservadas en integration/docker-compose.yml.
- LDAP operaciones en logs y ldapi para administración local; seis cuentas añadidas desde LDIF existente con credenciales nuevas privadas.
- Postfix log de entrega a archivo y Dovecot logs al contenedor.
- Apache tiempos LDAP acotados y respaldo del sitio/config en instalador.
- LDAP_HOST/LDAP_PORT parametrizables en instaladores web y correo (389/1389).
- FTP sin credenciales predeterminadas en instalador/cliente, rango Docker alineado 40000-40100; guía de usuarios corregida.
- Cliente usa uid reales; no imprime claves.
- Tests MAIL con asunto único, FETCH cuerpo y rechazo específico; FTP exige códigos de rechazo.
- test-official.py y audit-run.py registran 33 ID, seis logins, caída/recuperación LDAP, persistencia, puertos y logs.
- Inventario Windows/VirtualBox reutilizable y documentación/PDF reproducible.
- Guía LDAP elimina contraseñas expuestas; coordinar rotación en Mac. No se cambia historia Git ni hashes históricos del equipo.

Validación: ver evidencias/integration/actual/calidad.txt, suite-existente.txt y matriz-final.json. Instaladores para VMs se verificaron por sintaxis y configuración renderizada; no se instalaron en las computadoras remotas del grupo.
''')
write('instrucciones-arranque.md','''# Operación del montaje validado

Desde la raíz en PowerShell:

```powershell
docker desktop start
python integration/audit-run.py
```

El script necesita Python 3 y Docker, puede repetirse y conserva datos; actualiza las claves de las seis cuentas con los valores privados persistidos, sin tocar computadoras ajenas. Copia temporalmente secretos al cliente y los elimina al terminar. La clave FTP privada requiere siempre el override del montaje:

```powershell
docker compose -f integration/docker-compose.yml -f .git/lab5-private/compose.private.json up -d --wait
docker compose -f integration/docker-compose.yml -f .git/lab5-private/compose.private.json stop
```

No utilizar down -v: eliminaría los volúmenes. Para recuperar, conservar volúmenes actuales y usar sus backups privados. Respaldo lógico LDAP: .git/lab5-private/ldap-before-0.ldif y -1.ldif; export rotado privado: usuarios-rotados.ldif. Estos backups son del montaje local, no del Mac del compañero. Reproducir una auditoría genera nuevas evidencias y reemplaza los archivos de la ejecución actual; copiar esa carpeta antes si se desea conservar el historial.

Secretos: .git/lab5-private/credentials.json. No adjuntar, registrar ni subir esa carpeta. Dos usuarios reales de correo: nmolina y jvalladares. LDAP/IMAP usan uid sin dominio; dirección email uid@aerolinea.redes.test.

Para Thunderbird en una LAN aislada confirmada: servidor mail.aerolinea.redes.test, IMAP 143, SMTP 587, contraseña normal y sin TLS solamente en esa red. Verificar DNS real previamente. La integración host usa puertos 1143/1587 por localhost y no configura por sí sola el FQDN del Windows; no editar hosts para simular DNS. Thunderbird debe probarse desde un cliente que resuelva y alcance la red requerida.

Para el LDAP del Mac con forwarding confirmado: sudo LDAP_HOST=ldap.aerolinea.redes.test LDAP_PORT=1389 ./mail/scripts/install.sh (y web/scripts/install.sh). Guardar configuración previa y probar bind por FQDN antes. Estos comandos no se ejecutaron remotamente.

Reporte reproducible: python -m pip install reportlab; python docs/reporte/generar-reporte.py. Inventario: powershell -NoProfile -ExecutionPolicy Bypass -File virtualbox/diagnostico-host.ps1. No requiere alterar DNS de Windows.
''')
write('pendientes-reales.md','''# Pendientes que requieren intervención externa

1. Conectar un segundo equipo físico del grupo a la misma red y proporcionar acceso autorizado o ejecutar la matriz desde ese equipo. Confirmar IP actuales de los cinco servidores, puerto LDAP publicado y rutas; no reutilizar 10.223.12.x sin verificarlas.
2. Confirmar un segmento aislado para servicios sin TLS y una IP fija/reservada para DNS con el administrador legítimo del DHCP. No se conoce el pool DHCP del router doméstico y no se modificó.
3. El responsable LDAP remoto debe rotar las credenciales comprometidas y exportar nuevos hashes; coordinar web/correo/Thunderbird. Este montaje local ya tiene seis claves nuevas, pero los fixtures adicionales siguen siendo públicos y solo deben quedar aislados.
4. Instalar/configurar Thunderbird en el cliente autorizado y capturar configuración, login, envío/recepción entre nmolina y jvalladares. MAIL-02/03/06 no aprobados sin esas pruebas. Capturar también navegador/FTP según el PDF. No se fabricaron capturas.
5. Repetir los 33 casos en LAN, incluidos reinicios controlados y WEB-05 con recuperación; guardar máquina/fecha/logs. Revisar el reporte posterior a esa ejecución y validar con docente el dominio ASCII frente a la tilde del PDF y cualquier entrega tardía.

No se requiere crear otra VM para la integración actual. El estado saved de GNS3 y la falta de memoria hacen preferible conservarla. Para inspeccionar funciones Windows opcionales con DISM sí se necesita una consola elevada; esto no bloquea Docker validado.
''')
write('reporte/requirements.txt','reportlab>=4,<6\n')
styles=getSampleStyleSheet()
styles['BodyText'].fontSize=9
styles['BodyText'].leading=13
styles['Title'].alignment=TA_CENTER
pdf=SimpleDocTemplate(str(DOCS/'reporte/Laboratorio_5_Redes_Entrega.pdf'),title='Laboratorio 5 Redes - auditoría y evidencia',author='Grupo AeroQuetzal',pagesize=(595.28,841.89),rightMargin=42,leftMargin=42,topMargin=42,bottomMargin=42)
story=[]
def para(text,style='BodyText'): story.append(Paragraph(escape(text),styles[style])); story.append(Spacer(1,6))
para('Laboratorio 5 - Servicios de capa 7','Title')
para('CC3067 Redes - Universidad del Valle de Guatemala','Heading2')
para(intro)
para('Estado de entrega: integración Docker validada; demostración completa en LAN y Thunderbird pendiente. Este documento conserva bloqueos explícitos y no certifica cumplimiento total.')
para('Introducción','Heading1')
para('Se auditó y completó la infraestructura existente para DNS, identidad LDAP, web, correo y FTP. La prioridad fue demostrar comunicación entre servicios, conservar el trabajo del equipo y producir resultados reproducibles con alcance preciso.')
para('Roles y responsables','Heading1')
roles=[['Integrante','Cuenta LDAP','Responsabilidad verificada / por confirmar'],['Fernando Ruiz','fruiz','Integrante; asignación final por confirmar'],['Hugo Barillas','hbarillas','Integrante; asignación final por confirmar'],['Ian Cumes','icumes','DNS: atribución en docs/comparacion-repositorios'],['Javier Valladares','jvalladares','LDAP: evidencia Lima con usuario javier'],['Nery Molina','nmolina','Host Windows auditado en esta ejecución'],['Milton Polanco','mpolanco','Integrante; asignación final por confirmar']]
t=Table([[Paragraph(escape(c),styles['BodyText']) for c in row] for row in roles],colWidths=[110,75,325],repeatRows=1)
t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e4eafa')),('GRID',(0,0),(-1,-1),0.3,colors.grey),('VALIGN',(0,0),(-1,-1),'TOP')]))
story.append(t); story.append(Spacer(1,12))
para('Arquitectura y rutas','Heading1')
d=Drawing(500,190)
boxes=[(145,150,210,30,'NERY Windows / Docker Desktop'),(145,105,210,30,'Bridge 172.30.0.0/24 / gateway .1'),(0,45,80,35,'DNS .53 / 53'),(85,45,80,35,'LDAP .11 / 389'),(170,45,100,35,'Web .12 / 80'),(275,45,120,35,'Mail .13 / 25,587,143'),(400,45,100,35,'FTP .14 / 21'),(145,0,210,30,'Cliente .20 / FQDN por BIND9')]
for x,y,w,h,label in boxes:
    d.add(Rect(x,y,w,h,fillColor=colors.HexColor('#e9eff9'),strokeColor=colors.HexColor('#49699f'))); d.add(String(x+5,y+13,label,fontSize=8))
d.add(Line(250,150,250,135))
for x in [40,125,220,335,450]: d.add(Line(250,105,x,80)); d.add(Line(x,45,250,30))
story.append(d)
para('Host Ethernet 192.168.1.22 -> gateway 192.168.1.1. La LAN del grupo está pendiente. Ubuntu WSL2 y GNS3 se preservan. Consultar arquitectura-final.md para diagrama Mermaid completo, dependencias, publicaciones al host y reutilización AeroQuetzal.')
para('Direccionamiento y MAC','Heading1')
for line in table.splitlines()[2:]: para(line.strip('|').replace('|',' / '))
para('Resolución DNS','Heading1')
for line in dns_table.splitlines()[2:]: para(line.strip('|').replace('|',' / '))
para('Configuraciones relevantes','Heading1')
para('Se muestran las plantillas del repositorio con DOMAIN/BASE_DN sustituidos por los valores de este montaje y PASV_ADDRESS=172.30.0.14. Validación de configuraciones efectivamente cargadas: calidad.txt y logs de arranque. La variante LDAP 1389 solo se verificó por sintaxis, sin servidor remoto.')
for title,path in [('Zona BIND9','integration/dns/db.aerolinea.redes.test'),('Apache LDAP y sesiones','web/config/aerolinea.conf'),('Postfix','mail/config/postfix/main.cf'),('Dovecot','mail/config/dovecot/99-aerolinea.conf'),('vsftpd','ftp/docker/vsftpd.conf')]:
    para(title+' - '+path,'Heading2')
    text=(ROOT/path).read_text(encoding='utf8')
    text=text.replace('BASE_DN','dc=aerolinea,dc=redes,dc=test').replace('DOMAIN','aerolinea.redes.test')
    if title=='vsftpd': text=text.replace('pasv_address=127.0.0.1','pasv_address=172.30.0.14')
    text='\n'.join(line for line in text.splitlines() if line.strip() and not line.strip().startswith(('#','//')))
    story.append(Preformatted(text,styles['Code'],maxLineLength=95)); story.append(Spacer(1,10))
para('LDIF y cuentas','Heading2')
para('Se reutilizó ldap/ldif/usuarios-laboratorio.ldif. Las seis cuentas se importaron sin borrar datos existentes y se asignaron nuevos hashes SSHA privados. El LDIF del repositorio contiene hashes históricos asociados a claves publicadas y no debe considerarse una fuente segura de credenciales actuales. La exportación rotada permanece fuera del índice Git.')
para('Matriz completa y evidencias','Heading1')
para(f"Docker: {totals['PASS']} PASS, {totals['FAIL']} FAIL, {totals['BLOCKED']} BLOCKED. LAN física: 33 BLOCKED. Fechas y máquinas exactas en matriz-final.json.")
t=Table([['ID','Docker','LAN','Evidencia']]+[[r['id'],r['status'],'BLOCKED','matriz-final.json / '+r['id']] for r in rows],colWidths=[65,65,65,315],repeatRows=1)
t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e4eafa')),('GRID',(0,0),(-1,-1),0.3,colors.grey),('FONTSIZE',(0,0),(-1,-1),8),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#f3f5f8')])]))
story.append(t)
para('Detalle de procedimientos y resultados','Heading1')
for r in rows:
    para(r['id']+' / '+r['status'],'Heading2')
    para('Fecha UTC: '+r['time']+'; cliente: '+r['machine']+'; alcance: '+r['scope'])
    para('Procedimiento: '+r['procedure'])
    para('Esperado: '+r['expected'])
    observed=r['observed']
    if r['id']=='INT-02': observed=observed[-250:]
    elif r['id']=='INT-03': observed='Puertos por servicio comprobados con ss -lntup; evidencia completa en INT-03.txt.'
    elif r['id']=='WEB-05': observed=observed[-1200:]
    para('Observado: '+observed[:1800])
para('Problemas, soluciones y límites','Heading1')
for p in audit.split('## Hallazgos y efecto')[1].split('## Resultado')[0].strip().split('\n\n'): para(p)
para('Evidencias verificables','Heading1')
para('docs/evidencias/red: inventario-host.txt, virtualbox-info.txt, interfaces-ubuntu.txt, rutas.txt, dns-cliente.txt, mac-addresses.md, direccionamiento.md, conectividad.txt y reinicio-red.txt.')
para('docs/evidencias/integration/actual: matriz-final.json, suite-existente.txt, matriz-protocolos.txt, despues-reinicio.txt, persistencia.txt, WEB-05.txt, INT-03.txt, logs-*.txt, interfaces-*.json y calidad.txt. Se conservan evidencias históricas de DNS/LDAP con sus fechas originales. No se fabricaron capturas gráficas.')
para('Conclusiones','Heading1')
para('La comunicación DNS/LDAP/Apache/Postfix/Dovecot/vsftpd se demostró desde un cliente Docker separado y se repitió después del reinicio controlado. Las seis cuentas del grupo funcionan con claves nuevas en el montaje local. La entrega completa requiere demostrar la red entre computadoras físicas, completar Thunderbird y obtener las capturas del procedimiento académico. No se declara lista la demostración completa del laboratorio.')
def footer(canvas,doc):
    canvas.setFont('Helvetica',8); canvas.drawString(42,25,'CC3067 - Auditoría 11 octubre 2026 - Alcance Docker'); canvas.drawRightString(553,25,str(doc.page))
pdf.build(story,onFirstPage=footer,onLaterPages=footer)
print('PDF y documentación generados:',DOCS/'reporte/Laboratorio_5_Redes_Entrega.pdf')
