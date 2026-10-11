# Operación del montaje validado

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
