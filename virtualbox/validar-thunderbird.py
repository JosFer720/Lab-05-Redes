#!/usr/bin/env python3
"""Conecta, envÃ­a y lee desde Thunderbird real; conserva capturas y resultados.
Requiere perfil de laboratorio y proxy SSH funcionando. No usa smtplib/imaplib.
"""
import datetime,json,time
from pathlib import Path
from marionette_driver.marionette import Marionette
ROOT=Path(__file__).resolve().parent.parent
EVIDENCE=ROOT/'docs/evidencias/virtualbox'
def main():
    EVIDENCE.mkdir(parents=True,exist_ok=True)
    m=Marionette('127.0.0.1',port=2828);m.start_session();m.set_context('chrome');m.timeout.script=90
    results=[]
    def record(test,fn):
        try: observed=fn();status='PASS'
        except Exception as exc: observed=str(exc);status='FAIL'
        results.append(dict(id=test,status=status,observed=observed,time=datetime.datetime.now(datetime.timezone.utc).isoformat(),scope='Thunderbird Windows real -> SSH SOCKS -> servicios nativos VirtualBox'))
        print(test,status,str(observed)[:500],flush=True)
    subject='VirtualBox-Thunderbird-'+str(time.time_ns())
    message=ROOT/'.git/virtualbox-private/thunderbird-message.eml'
    message.write_bytes((f'From: nmolina@aerolinea.redes.test\r\nTo: jvalladares@aerolinea.redes.test\r\nSubject: {subject}\r\nMessage-ID: <{subject}@aerolinea.redes.test>\r\nMIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\nEnvio y lectura reales desde Thunderbird. {subject}\r\n').encode())
    def configured():
        data=m.execute_script('''const {MailServices}=ChromeUtils.importESModule("resource:///modules/MailServices.sys.mjs");return Array.from(MailServices.accounts.allServers).filter(s=>s.type=="imap").map(s=>({uid:s.username,host:s.hostname,port:s.port,auth:s.authMethod,socket:s.socketType}));''')
        assert {r['uid'] for r in data}=={'nmolina','jvalladares'}
        assert all(r['host']=='mail.aerolinea.redes.test' and r['port']==143 for r in data)
        m.execute_script('document.getElementById("tabmail").openTab("contentTab",{url:"about:accountsettings"});')
        time.sleep(2)
        (EVIDENCE/'thunderbird-configuracion.png').write_bytes(m.screenshot(format='binary'))
        return data
    def receive(uid):
        return m.execute_async_script('''const done=arguments[arguments.length-1];const uid=arguments[0];const {MailServices}=ChromeUtils.importESModule("resource:///modules/MailServices.sys.mjs");const s=Array.from(MailServices.accounts.allServers).find(s=>s.username==uid&&s.type=="imap");const win=Cc["@mozilla.org/messenger/msgwindow;1"].createInstance(Ci.nsIMsgWindow);const listener={QueryInterface:ChromeUtils.generateQI(["nsIUrlListener"]),OnStartRunningUrl(){},OnStopRunningUrl(url,status){done({uid,status,folders:Array.from(s.rootFolder.subFolders).map(f=>({name:f.name,uri:f.URI}))});}};const inbox=s.rootFolder.getFolderWithFlags(Ci.nsMsgFolderFlags.Inbox);if(inbox) MailServices.imap.selectFolder(inbox,listener,win);else MailServices.imap.discoverAllFolders(s.rootFolder,listener,win);''',script_args=[uid])
    def login():
        data=[receive(uid) for uid in ['nmolina','jvalladares']]
        assert all(r['status']==0 for r in data),data
        return data
    def sendread():
        sent=m.execute_async_script('''const done=arguments[arguments.length-1];const {MailServices}=ChromeUtils.importESModule("resource:///modules/MailServices.sys.mjs");const account=Array.from(MailServices.accounts.accounts).find(a=>a.incomingServer?.username=="nmolina");const smtp=MailServices.outgoingServer.getServerByIdentity(account.defaultIdentity);const file=Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);file.initWithPath(arguments[0]);smtp.sendMailMessage(file,MailServices.headerParser.parseEncodedHeaderW("jvalladares@aerolinea.redes.test"),[],account.defaultIdentity,"nmolina@aerolinea.redes.test","",null,false,arguments[1],{onSendStart(){},onSendStop(uri,status,security,error){done({status,error});}});''',script_args=[str(message),subject])
        assert sent['status']==0,sent
        for _ in range(10):
            data=receive('jvalladares');assert data['status']==0,data
            found=m.execute_script('''const {MailServices}=ChromeUtils.importESModule("resource:///modules/MailServices.sys.mjs");const s=Array.from(MailServices.accounts.allServers).find(s=>s.username=="jvalladares");const inbox=s.rootFolder.getFolderWithFlags(Ci.nsMsgFolderFlags.Inbox);if(!inbox)return null;const hdr=Array.from(inbox.messages).find(h=>h.subject==arguments[0]);if(!hdr)return null;const tab=document.getElementById("tabmail");tab.openTab("mailMessageTab",{messageURI:inbox.getUriForMsg(hdr)});return {subject:hdr.subject,from:hdr.author,to:hdr.recipients,uri:inbox.getUriForMsg(hdr)};''',script_args=[subject])
            if found:
                time.sleep(2)
                body=m.execute_script('return document.getElementById("tabmail").currentTabInfo.browser?.contentDocument?.body?.textContent;')
                assert body and subject in body,'El cuerpo no se mostr? en Thunderbird'
                (EVIDENCE/'thunderbird-recibido.png').write_bytes(m.screenshot(format='binary'))
                return {'smtp':sent,'recibido':found}
            time.sleep(2)
        raise AssertionError('Thunderbird no encontrÃ³ el mensaje Ãºnico')
    try:
        record('MAIL-02',configured);record('MAIL-03',login);record('MAIL-06',sendread)
    finally:
        (EVIDENCE/'resultados-thunderbird.json').write_text(json.dumps(results,indent=2,ensure_ascii=False),encoding='utf8');m.delete_session()
    return int(any(r['status']!='PASS' for r in results))
if __name__=='__main__': raise SystemExit(main())
