#!/usr/bin/env python3
"""Capturas reales del sitio servido por Apache, desde Edge en Windows."""
import json,os
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parent.parent
E=ROOT/'docs/evidencias/virtualbox'
def main():
    secrets=json.loads((ROOT/'.git/lab5-private/credentials.json').read_text())
    exe=Path(os.environ['ProgramFiles(x86)'])/'Microsoft/Edge/Application/msedge.exe'
    with sync_playwright() as p:
        browser=p.chromium.launch(executable_path=str(exe),headless=True,proxy={'server':'socks5://127.0.0.1:10805'})
        context=browser.new_context(viewport={'width':1440,'height':1000})
        page=context.new_page()
        response=page.goto('http://www.aerolinea.redes.test',wait_until='networkidle',timeout=60000)
        assert response.status==200,response.status
        page.screenshot(path=str(E/'web-home.png'),full_page=True)
        page.goto('http://www.aerolinea.redes.test/login/',wait_until='networkidle',timeout=60000)
        page.locator('input[name="httpd_username"]').fill('nmolina')
        page.locator('input[name="httpd_password"]').fill(secrets['passwords']['nmolina'])
        page.locator('button[type="submit"]').click()
        page.wait_for_url('**/privado/**',timeout=30000)
        page.wait_for_load_state('networkidle')
        page.screenshot(path=str(E/'web-privado.png'),full_page=True)
        print('Capturas Edge reales guardadas; portada y sesión LDAP autorizada:',page.url)
        context.close();browser.close()
if __name__=='__main__':main()
