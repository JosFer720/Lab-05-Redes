# Integración local

## Auditoría completa y cuentas reales del grupo

Desde la raíz: `python integration/audit-run.py`. Requiere Python 3 y Docker Desktop activo.
El comando conserva la implementación, crea las seis cuentas desde el LDIF existente,
genera claves exclusivas, verifica 33 identificadores, ejecuta la suite anterior,
detiene LDAP temporalmente y reinicia los cinco servicios con recuperación verificada.
Las pruebas de Thunderbird quedan BLOCKED hasta obtener evidencia gráfica real.

Los secretos y el override Compose se guardan en `.git/lab5-private/` y no se publican.
Para administrar este montaje usar ambos archivos Compose, incluida
`.git/lab5-private/compose.private.json`, evitando restablecer la clave FTP del fixture.
Los puertos publicados están limitados a `127.0.0.1`: este montaje es una integración
aislada y no una demostración desde las computadoras físicas del grupo.
LDAP, Maildir y FTP usan volúmenes; no ejecutar `down -v` si se desean conservar.
Las MAC originalmente generadas se fijaron tras comprobar que cambiaban al reiniciar.
La subred Docker 172.30.0.0/24 y WSL 172.30.208.0/20 son redes distintas sin solapamiento.

## Fixture básico (dos cuentas de prueba)

```bash
cd integration
docker compose up -d --build --wait --wait-timeout 120
docker compose exec client /tests/test-all.sh
docker compose down
```

Requiere Docker con contenedores Linux. Todos los servicios se construyen desde
este repositorio: no hace falta una imagen FTP previa ni compilar el sitio a mano.
Compose espera que DNS, LDAP, web, correo y FTP estén listos antes de iniciar el cliente.

Servicios publicados en Windows, macOS o Linux:

- DNS UDP y TCP en 15353 (el puerto 53 se usa dentro de la red de contenedores)
- LDAP en 1389
- Web en 8080
- SMTP en 2525
- Submission en 1587
- IMAP en 1143

La zona de integración usa las IPs fijas `172.30.0.x` y se copia al cliente para
comparar las respuestas DNS con las IPs esperadas. La zona de las VMs en `dns/zones/`
mantiene las direcciones de la red del grupo; se actualiza con `dns/scripts/set-ips.sh`.
Los usuarios `usuario1` y `usuario2` y sus claves son datos de prueba de este entorno.

Consulta desde el host: `dig @127.0.0.1 -p 15353 aerolinea.redes.test SOA`.
El entorno permite verificar la integración local; las evidencias de las VMs
del grupo se obtienen al ejecutar las pruebas en su red real.
