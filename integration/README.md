# Integración local

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
