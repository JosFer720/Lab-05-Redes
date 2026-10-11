#!/usr/bin/env python3
"""Configura dos cuentas del laboratorio en una sesión real y aislada de Thunderbird.
Thunderbird debe iniciarse con --marionette --remote-allow-system-access y el perfil
.git/virtualbox-private/thunderbird-profile. No modifica perfiles personales.
"""
import json
from pathlib import Path
from marionette_driver.marionette import Marionette
ROOT=Path(__file__).resolve().parent.parent
def session():
    m=Marionette('127.0.0.1',port=2828); m.start_session(); m.set_context('chrome'); return m
if __name__=='__main__':
    secrets=json.loads((ROOT/'.git/lab5-private/credentials.json').read_text())
    m=session()
    try:
        result=m.execute_script('''
const {MailServices}=ChromeUtils.importESModule("resource:///modules/MailServices.sys.mjs");
const passwords=arguments[0];
const result=[];
for (const uid of ["nmolina","jvalladares"]) {
 let server=Array.from(MailServices.accounts.allServers).find(s=>s.type=="imap"&&s.username==uid);
 if (!server) {
  server=MailServices.accounts.createIncomingServer(uid,"mail.aerolinea.redes.test","imap");
  server.port=143; server.socketType=0; server.authMethod=3;
  server.prettyName=uid+"@aerolinea.redes.test";
  server.setBoolValue("check_new_mail",false);
  const account=MailServices.accounts.createAccount(); account.incomingServer=server;
  const identity=MailServices.accounts.createIdentity(); identity.email=uid+"@aerolinea.redes.test"; identity.fullName=uid;
  account.addIdentity(identity);
  if (uid=="nmolina") MailServices.accounts.defaultAccount=account;
 }
 let smtp=Array.from(MailServices.outgoingServer.servers).find(s=>s.username==uid);
 if (!smtp) smtp=MailServices.outgoingServer.createServer("smtp");
 smtp=smtp.QueryInterface(Ci.nsISmtpServer);
 smtp.hostname="mail.aerolinea.redes.test"; smtp.port=587; smtp.socketType=0; smtp.authMethod=3; smtp.username=uid;
 const account=Array.from(MailServices.accounts.accounts).find(a=>a.incomingServer==server);
 account.defaultIdentity.smtpServerKey=smtp.key;
 server.password=passwords[uid]; smtp.password=passwords[uid];
 result.push({uid,imap:server.hostname,port:server.port,smtpPort:smtp.port});
}
return result;
''',script_args=[secrets['passwords']])
        print(json.dumps(result,ensure_ascii=False))
    finally: m.delete_session()
