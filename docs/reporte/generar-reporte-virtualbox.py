#!/usr/bin/env python3
"""Reporte nuevo desde evidencias VirtualBox; adjunta antecedente Docker intacto."""
import collections,datetime,json,shutil
from pathlib import Path
from xml.sax.saxutils import escape
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle,PageBreak,Image,Preformatted
from pypdf import PdfWriter
ROOT=Path(__file__).resolve().parents[2]
E=ROOT/'docs/evidencias/virtualbox'
REPORT=ROOT/'docs/reporte'
def main():
    rows=json.loads((E/'matriz-final.json').read_text(encoding='utf8'))
    assert len(rows)==33
    totals=collections.Counter(r['status'] for r in rows)
    now=datetime.datetime.now(datetime.timezone.utc).isoformat()
    vm=json.loads((ROOT/'.git/virtualbox-private/vm.json').read_text())
    styles=getSampleStyleSheet();styles['BodyText'].fontSize=9;styles['BodyText'].leading=13
    story=[]
    def p(text,style='BodyText'):story.append(Paragraph(escape(str(text)).replace('\n','<br/>'),styles[style]));story.append(Spacer(1,7))
    def table(data,widths=None):
        t=Table([[Paragraph(escape(str(c)),styles['BodyText']) for c in row] for row in data],colWidths=widths,repeatRows=1,hAlign='LEFT')
        t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e7edf5')),('VALIGN',(0,0),(-1,-1),'TOP'),('LINEBELOW',(0,0),(-1,0),.5,colors.HexColor('#315273')),('BOTTOMPADDING',(0,0),(-1,-1),6),('TOPPADDING',(0,0),(-1,-1),6),('LINEBELOW',(0,1),(-1,-1),.2,colors.lightgrey)]));story.append(t);story.append(Spacer(1,10))
    p('Laboratorio 5 · Redes CC3067','Title');p('Validación nativa en Oracle VirtualBox','Heading1')
    p(f'Generado {now}. Resultado de esta ejecución: {totals["PASS"]} PASS, {totals["FAIL"]} FAIL, {totals["BLOCKED"]} BLOCKED de 33 casos.')
    p('Alcance: Windows es cliente independiente por la red host-only y Ubuntu es el servidor nativo. Ambos se ejecutan en una computadora física. No se validó una segunda computadora del grupo, porque el usuario confirmó que no está disponible.')
    p('El antecedente Docker se conserva como PDF separado y se adjunta al final de esta entrega. Sus 30 PASS, 0 FAIL y 3 BLOCKED pertenecen a la ejecución anterior y no se contabilizan en la matriz VirtualBox.')
    p('Máquina virtual y decisión','Heading2')
    p('GNS3 VM se restauró normalmente y se inspeccionó su consola. Es un appliance dedicado con proyectos en /opt/gns3 y Ubuntu resolute. Se devolvió a estado guardado. Se creó una VM separada para conservar su función y sus datos.')
    table([['Campo','Valor'],['Nombre',vm['name']],['UUID','d248d4a5-ca81-44cf-96a9-73a3b758962e'],['Sistema','Ubuntu 24.04.4 LTS x86_64'],['CPU / RAM','1 CPU / 1536 MB; recursos ajustados a la memoria disponible'],['Disco','25 GiB dinámico; raíz crecida por cloud-init'],['Administración','SSH por clave, labadmin@192.168.56.10'],['Snapshot inicial','Ubuntu-inicial-SSH, antes de instalar servicios']], [120,390])
    p('Se diagnosticaron intentos de arranque con bloqueos del kernel. La configuración utilizada queda registrada en vbox-info.txt. La imagen oficial, el SHA256 verificado y el inventario del invitado se conservan como evidencia; los discos anteriores permanecen fuera de Git.')
    p(vm['source']);p('SHA256 imagen: '+vm['image_sha256'])
    story.append(PageBreak());p('Direccionamiento y servicios','Heading1')
    table([['Interfaz','Conexión','IPv4','MAC'],['enp0s3','NAT','10.0.2.15/24','08:00:27:5c:08:8e'],['enp0s8','Host-only','192.168.56.10/24','08:00:27:b1:41:d6'],['Windows host-only','Cliente','192.168.56.1/24','0a:00:27:00:00:11']], [80,95,130,205])
    p('Gateway Ubuntu: 10.0.2.2 por NAT. La interfaz host-only no tiene gateway. La LAN Windows 192.168.1.0/24 no se solapa con 192.168.56.0/24. No se modificó el router ni la DNS global de Windows.')
    table([['Servicio','Unidad systemd','Puertos'],['BIND9','named','53 TCP/UDP'],['OpenLDAP','slapd','389 TCP y ldapi local'],['Apache','apache2','80 TCP'],['Postfix','postfix, postfix@-','25 y 587 TCP'],['Dovecot','dovecot','143 TCP; LMTP socket local'],['vsftpd','vsftpd','21 TCP, pasivo 40000–40100']], [130,170,210])
    p('Las unidades están habilitadas para el arranque. Los PID y grupos /system.slice, ss -lntup, systemd-detect-virt=oracle y la validación de configuración figuran en los archivos de evidencia nativos.')
    p('La comprobación exige seis estados exactamente active y usa postfix@-.service, que ejecuta el master, junto con las otras cinco unidades. postfix.service es la unidad auxiliar. Se conservan Ubuntu-inicial-SSH y Lab5-servicios-persistentes; el segundo snapshot se tomó con la VM apagada después de cancelar un intento en vivo que no terminaba.')
    p('Se conservó el kernel panic del primer reinicio en reinicio-intento-fallido.log. El ajuste GRUB quiet noapic clocksource=acpi_pm corrige el temporizador de esta VM; el resultado definitivo del reinicio se determina por INT-02, no por un encendido manual.')
    p('UFW limita el tráfico entrante de aplicación a la interfaz host-only y al segmento 192.168.56.0/24. La única redirección NAT es SSH en 127.0.0.1:22225. Postfix restringe mynetworks a loopback; la prueba de relay externo se registra por separado.')
    p('Zona DNS efectiva','Heading2')
    zone=(E/'zona-efectiva.txt').read_text(encoding='utf8')
    story.append(Preformatted(zone,styles['Code']));story.append(Spacer(1,10))
    table([['Nombre','A / MX'],*[['ns1 / ldap / www / mail / ftp','192.168.56.10']],['aerolinea.redes.test MX','10 mail.aerolinea.redes.test.']], [260,250])
    story.append(PageBreak());p('Identidad, sitio y cliente','Heading1')
    table([['UID','Identidad','Correo'],['fruiz','Fernando Ruiz','fruiz@aerolinea.redes.test'],['hbarillas','Hugo Barillas','hbarillas@aerolinea.redes.test'],['icumes','Ian Cumes','icumes@aerolinea.redes.test'],['jvalladares','Javier Valladares','jvalladares@aerolinea.redes.test'],['nmolina','Nery Molina','nmolina@aerolinea.redes.test'],['mpolanco','Milton Polanco','mpolanco@aerolinea.redes.test']], [80,140,290])
    p('Se reutilizaron las identidades del LDIF del repositorio con las credenciales renovadas. Base dc=aerolinea,dc=redes,dc=test; unidad ou=People. Las contraseñas, claves SSH y perfiles de clientes permanecen en archivos privados fuera del control de versiones.')
    p('Apache sirve el sitio original web/site, compilado con Node y npm nativos. La autenticación por formulario consulta LDAP; se verifican seis inicios/cierres de sesión, rechazo de credenciales y caída temporal de slapd con restauración inmediata.')
    p('npm audit registró siete alertas altas en dependencias de desarrollo de shadcn. Se conserva npm-audit.json; no se aplicó el cambio de versión incompatible propuesto por npm. Apache sirve la compilación estática. Estas alertas siguen pendientes y no están cubiertas por los 33 casos de redes.')
    p('El cliente Windows consulta BIND mediante DNS real dentro del proceso de pruebas. Thunderbird y el navegador usan SOCKS por SSH con resolución de nombres en Ubuntu; no se sustituyeron nombres en hosts ni se cambió la DNS global del equipo. Thunderbird usa un perfil exclusivo del laboratorio.')
    p('Correo: IMAP 143, Submission 587, autenticación LDAP con contraseña normal. El servidor admite estos protocolos sin TLS dentro del laboratorio; el cliente Thunderbird circula por el túnel SSH. Las pruebas de Thunderbird se ejecutan en la aplicación real mediante Marionette y se distinguen de las pruebas complementarias de smtplib/imaplib.')
    for filename,title in [('web-home.png','Sitio original desde Windows'),('thunderbird-configuracion.png','Configuración real de Thunderbird'),('thunderbird-recibido.png','Mensaje recibido en Thunderbird')]:
        path=E/filename
        if path.exists():
            story.append(PageBreak());p(title,'Heading1');im=Image(str(path));scale=min(510/im.imageWidth,650/im.imageHeight);im.drawWidth=im.imageWidth*scale;im.drawHeight=im.imageHeight*scale;story.append(im)
    story.append(PageBreak());p('Matriz de 33 casos','Heading1')
    table([['Caso','Resultado','Observado'],*[[r['id'],r['status'],str(r['observed'])[:330]] for r in rows]], [62,62,386])
    p('Cada caso incluye esperado, observado, fecha, máquina, alcance y procedimiento completo en matriz-final.json. PASS requiere ejecución aprobada; FAIL indica ejecución fallida; BLOCKED indica falta de recursos. El archivo conserva las limitaciones específicas de cada prueba.')
    story.append(PageBreak());p('Persistencia y reproducibilidad','Heading1')
    reboot=next(r for r in rows if r['id']=='INT-02');p(reboot['status']+': '+str(reboot['observed']))
    p('Evidencias principales: inventario-ubuntu.txt, vbox-info.txt, windows-ip.txt, windows-arp.txt, dns-windows.txt, resultados-windows.json, resultados-thunderbird.json, matriz-final.json, WEB-05.txt, antes-reinicio.txt, despues-reinicio.txt, INT-03.txt, logs-nativos.txt y capturas PNG reales.')
    p('Volver a encender mañana desde PowerShell en el repositorio:')
    for cmd in ['powershell -ExecutionPolicy Bypass -File virtualbox/iniciar-vm.ps1','powershell -ExecutionPolicy Bypass -File virtualbox/estado-vm.ps1','powershell -ExecutionPolicy Bypass -File virtualbox/conectar-ssh.ps1','powershell -ExecutionPolicy Bypass -File virtualbox/iniciar-cliente.ps1','powershell -ExecutionPolicy Bypass -File virtualbox/abrir-web.ps1']:
        story.append(Preformatted(cmd,styles['Code']))
    p('Dentro de Ubuntu: sudo bash /opt/lab5/virtualbox/arrancar-servicios.sh; sudo bash /opt/lab5/virtualbox/verificar-servicios.sh. Las unidades habilitadas también arrancan automáticamente. Para apagar: detener-vm.ps1 solicita apagado ACPI normal.')
    p('Pendiente externo: repetición con computadoras físicas del grupo en una topología compartida. El despliegue host-only no demuestra acceso LAN de otro equipo. No se configuró bridge ni se expusieron protocolos sin TLS hacia Internet.')
    p('Antecedente adjunto','Heading1');p('El PDF de entrega añade a continuación el reporte anterior de Docker íntegro. Es antecedente histórico y está excluido de los resultados VirtualBox. Este PDF nativo también se conserva separado.')
    native=REPORT/'Laboratorio_5_Redes_VirtualBox.pdf'
    def footer(canvas,doc):canvas.setFont('Helvetica',8);canvas.drawString(42,24,'CC3067 · Validación nativa VirtualBox');canvas.drawRightString(A4[0]-42,24,str(doc.page))
    SimpleDocTemplate(str(native),pagesize=A4,rightMargin=42,leftMargin=42,topMargin=40,bottomMargin=40).build(story,onFirstPage=footer,onLaterPages=footer)
    old=REPORT/'Laboratorio_5_Redes_Antecedente_Docker.pdf'
    writer=PdfWriter();writer.append(str(native));writer.append(str(old));writer.write(str(REPORT/'Laboratorio_5_Redes_Entrega.pdf'));writer.close()
    matrix='| Caso | Estado | Observado |\n|---|---|---|\n'+'\n'.join('| '+r['id']+' | '+r['status']+' | '+str(r['observed'])[:250].replace('|','/').replace('\n',' ')+' |' for r in rows)
    (ROOT/'docs/matriz-pruebas-virtualbox.md').write_text('# Matriz VirtualBox — 33 casos\n\n'+f'{now}: {dict(totals)}. Windows independiente y servidor Ubuntu VirtualBox, mismo equipo físico.\n\n'+matrix+'\n\nProcedimientos completos y evidencias: [matriz-final.json](evidencias/virtualbox/matriz-final.json). Las pruebas LAN entre computadoras físicas quedan pendientes.\n',encoding='utf8')
    print('Reporte nativo, entrega con antecedente y matriz generados:',dict(totals))
if __name__=='__main__':main()
