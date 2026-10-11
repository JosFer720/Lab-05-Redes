# Cambios realizados

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
