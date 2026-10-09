# OpenLDAP en Ubuntu sobre Mac

Entrega de OpenLDAP para `JosFer720/Lab-05-Redes`. El despliegue inicial se
realizó con el instalador de `JosFer720/lab05-redes-prueba`, revisión
`7547f52`; aquí se incorpora esa implementación con sus configuraciones,
pruebas y evidencias originales.
Se usó Ubuntu Server 24.04 ARM64 en una VM nativa de Apple Virtualization
administrada con Lima. Fecha: 7 de octubre de 2026.

## Conexión

| Desde dónde | Dirección |
|---|---|
| VMs de la red del laboratorio | `ldap://ldap.aerolinea.redes.test:389` |
| Este Mac | `ldap://127.0.0.1:1389` |
| Otros equipos en la misma red del Mac | `ldap://10.223.12.169:1389` |

La IP del Mac fue comprobada el 7 de octubre de 2026 y corresponde a la red
conectada al preparar el laboratorio.
Puede cambiar al conectarse a otra red. El reenvío 1389 → 389 se activa al
encender la VM LDAP. La conexión desde otro equipo físico todavía requiere
probarse desde ese equipo.

- Base: `dc=aerolinea,dc=redes,dc=test`.
- Usuarios: `ou=People,dc=aerolinea,dc=redes,dc=test`.
- Administrador: `cn=admin,dc=aerolinea,dc=redes,dc=test`.
- Contraseña administrativa de laboratorio: `Lab5-AdminLDAP`.
- Búsquedas anónimas de `uid`, `cn`, `sn` y `mail` habilitadas para Apache y correo.
- `userPassword` oculto en consultas anónimas y a otros usuarios.

Todas las credenciales son las del plan y se usan únicamente en este laboratorio.
El transporte es LDAP sin TLS, como la configuración del repositorio.

| Usuario | Integrante | Contraseña de laboratorio |
|---|---|---|
| fruiz | Fernando Ruiz | Lab5-fruiz |
| hbarillas | Hugo Barillas | Lab5-hbarillas |
| icumes | Ian Cumes | Lab5-icumes |
| jvalladares | Javier Valladares | Lab5-jvalladares |
| nmolina | Nery Molina | Lab5-nmolina |
| mpolanco | Milton Polanco | Lab5-mpolanco |

El instalador recibió las seis filas desde
`/root/lab5-secrets/users.tsv`, con permisos 600, dentro de la VM.
Ese archivo privado no se añadió a Git. El directorio exportado en
[`usuarios-laboratorio.ldif`](../ldap/ldif/usuarios-laboratorio.ldif)
contiene las contraseñas como hashes SSHA y puede importarse en una base vacía.
No debe importarse directamente sobre entradas que ya existan.

## Encender y entrar

En el escritorio hay dos accesos:

- **OpenLDAP Lab5.command**: enciende LDAP y abre una terminal en el servidor.
- **Comprobar OpenLDAP Lab5.command**: enciende LDAP y el cliente y ejecuta las pruebas.

También funcionan estos comandos en la terminal del Mac:

```bash
limactl start lab5-ldap
ssh lab5-ldap
```

Dentro del servidor:

```bash
sudo systemctl status slapd
sudo journalctl -t slapd --since today
```

Desde el Mac, esta consulta llega al servidor real en Ubuntu:

```bash
ldapsearch -x -LLL -H ldap://127.0.0.1:1389 \
  -b ou=People,dc=aerolinea,dc=redes,dc=test \
  '(objectClass=inetOrgPerson)' uid cn sn mail
```

## Red de apoyo

| VM | Servicio | IP del laboratorio | Recursos |
|---|---|---|---|
| lab5-ns1 | BIND9 | 192.168.50.10 | 1 CPU, 1 GiB RAM |
| lab5-ldap | OpenLDAP | 192.168.50.11 | 1 CPU, 1 GiB RAM |
| lab5-cliente | Cliente Ubuntu de pruebas | 192.168.50.20 | 1 CPU, 1 GiB RAM |

Cada disco virtual tiene un límite de 8 GiB y ocupa espacio según su uso.
Las VMs comparten la red Lima `lab5`, modo `user-v2`, subred 192.168.50.0/24.
La puerta de enlace observada es **192.168.50.2**, aunque el plan daba .1 como
ejemplo. Se conservó una IP adicional de gestión por VM para el acceso SSH de
Lima. Ambas direcciones son fijas, DHCP está apagado y las VMs LDAP y cliente usan
10.223.12.73 como DNS del grupo. La VM ns1 se conserva como parte del montaje
local anterior. Los archivos reales están en `ldap/config/local/`.
No se añadieron entradas para resolver servicios en `/etc/hosts`.

El DNS local de apoyo tiene los registros del plan. Las direcciones .12, .13 y .14 están
reservadas para web, correo y FTP; esos servicios no se desplegaron como parte
de esta tarea. La VM FTP anterior permanece apagada.

Para resolver Internet desde esta red, BIND reenvía a 1.1.1.1 y 8.8.8.8,
con `forward only` y validación DNSSEC desactivada en este entorno local.
Las consultas DNSKEY necesarias para validar DNSSEC agotaban el tiempo de
espera y bloqueaban `apt`. La zona interna sigue siendo autoritativa.
Se preservaron las configuraciones anteriores en `/root/lab5-backups/dns/`.

## Conectar el Apache del repositorio

En una VM conectada a la misma red del laboratorio, la configuración actual
de `web/config/aerolinea.conf` ya coincide con este directorio:

```apache
AuthLDAPURL "ldap://ldap.aerolinea.redes.test/ou=People,dc=aerolinea,dc=redes,dc=test?uid,cn,mail?one"
```

Si Apache corre en otra computadora de la red física, el DNS de ese equipo
debe resolver `ldap.aerolinea.redes.test` a la IP actual del Mac y la URL debe
usar el puerto publicado:

```apache
AuthLDAPURL "ldap://ldap.aerolinea.redes.test:1389/ou=People,dc=aerolinea,dc=redes,dc=test?uid,cn,mail?one"
```

El mismo ajuste de host y puerto aplica a Postfix y Dovecot. No se modificaron
las configuraciones de esos servicios en este despliegue.

## Verificación y respaldos del 7 de octubre de 2026

Se ejecutaron la verificación local y las cuatro pruebas LDAP del repositorio.
Además, `client/tests/test-ldap-plan.py` comprueba 14 condiciones: DNS real,
resolvedor del cliente, seis usuarios exactos, bind válido de cada usuario,
contraseña incorrecta, usuario inexistente, atributos exactos y ocultamiento
de hashes. Los resultados y logs están en `docs/evidencias/ldap/`.

Se apagaron las tres VMs y se encendieron en orden **DNS → LDAP → cliente**.
La comprobación posterior verifica nuevamente las 14 condiciones y registra
los identificadores de arranque. `slapd` y `named` quedan habilitados para
iniciar al arrancar Ubuntu.

Lima con el controlador VZ no implementó el comando de snapshots. Se hicieron
copias APFS de discos y configuración con las VMs apagadas, fuera de iCloud y
del repositorio, en:

```text
~/Virtual Machines/Redes-Lab5-Respaldos/
  00-base/
  01-dns/
  02-ldap/
  02-ldap-repo-prueba/
```

Estos respaldos permiten recuperar las instancias en este Mac. Para restaurar,
primero detener la VM y preservar su estado actual; después recuperar su disco,
configuración y archivos VZ del mismo respaldo. No sobrescribir una VM encendida.


## Integración en la red física del grupo

La IP del Mac comprobada el 7 de octubre de 2026 fue **10.223.12.169**.
Actualizar esa dirección en DNS y en las pruebas si cambia la red. Se verificó un bind
LDAP por esa IP y el puerto 1389 desde el propio Mac. Falta la comprobación
desde las otras computadoras del grupo.

1. En el servidor DNS del grupo, el registro debe ser
   `ldap IN A 10.223.12.169`. Actualizar el serial de la zona, validarla y
   recargar BIND. Apache, correo y el cliente deben consultar ese DNS.
2. Desde el Ubuntu de Apache y desde el de correo, comprobar:

   ```bash
   dig +short ldap.aerolinea.redes.test
   nc -vz ldap.aerolinea.redes.test 1389
   ldapwhoami -x -H ldap://ldap.aerolinea.redes.test:1389 \
     -D 'uid=jvalladares,ou=People,dc=aerolinea,dc=redes,dc=test' -W
   ```

   El nombre debe devolver `10.223.12.169`. La contraseña de esta cuenta es
   `Lab5-jvalladares` y el bind debe devolver su DN.
3. Apache debe usar la URL con `:1389` indicada arriba. En el servidor de
   correo, editar los archivos desplegados:

   | Archivo | Directiva |
   |---|---|
   | `/etc/dovecot/dovecot-ldap.conf.ext` | `uris = ldap://ldap.aerolinea.redes.test:1389` |
   | `/etc/postfix/ldap-virtual-mailbox.cf` | `server_host = ldap://ldap.aerolinea.redes.test:1389` |

   Validar las configuraciones y reiniciar los servicios correspondientes.
   Los instaladores actuales usan el puerto LDAP predeterminado; si se
   ejecutan de nuevo, hay que conservar este ajuste de puerto.
4. Probar en el sitio web un usuario válido, una contraseña incorrecta y un
   usuario inexistente. En correo, comprobar autenticación y entrega entre
   dos usuarios. Guardar los resultados de las pruebas desde cada equipo.

El Mac y la VM LDAP deben permanecer encendidos durante las pruebas del grupo.


## Cambio al DNS del grupo: 10.223.12.73 (7 de octubre de 2026)

Se configuró `nameservers.addresses: [10.223.12.73]` en Netplan de
`lab5-ldap` y `lab5-cliente`, preservando sus IP y puerta de enlace.
`netplan generate` y `netplan apply` terminaron correctamente; `resolvectl`
confirma ese único DNS en ambas VMs. Los respaldos están dentro de cada VM
bajo `/root/lab5-backups/dns-grupo-20261007-213912` (LDAP) y
`/root/lab5-backups/dns-grupo-20261007-213913` (cliente).

Al verificar el cambio, el servidor 10.223.12.73 no respondió a consultas
DNS desde el Mac ni desde Ubuntu. Tampoco respondió la consulta por TCP 53.
La resolución de nombres del grupo queda pendiente de que ese servidor sea
accesible y atienda DNS por UDP y TCP 53. Las evidencias están en
`docs/evidencias/ldap/DNS-grupo-10.223.12.73.txt`.
OpenLDAP continúa activo y el bind por 10.223.12.169:1389 funciona.
Las matrices anteriores de 14/14 corresponden al montaje local anterior.

Para repetir la matriz desde la VM cliente cuando responda el DNS del grupo:

```bash
python3 /mnt/lab5/Lab-05-Redes/client/tests/test-ldap-plan.py \
  --dns-server 10.223.12.73 --port 1389 --expected-ip 10.223.12.169 \
  --output /home/javier/evidencias-ldap-grupo
```

El acceso del escritorio para comprobar OpenLDAP usa ahora esos valores.

## Validación de la entrega: 8 de octubre de 2026

Se encendió la VM LDAP y se ejecutó `client/tests/test-ldap.sh` desde el Mac
contra `ldap://127.0.0.1:1389`: las cuatro pruebas LDAP-01 a LDAP-04 pasaron.
La prueba de contraseña incorrecta exige el código LDAP 49 y la de atributos
comprueba `uid`, `cn`, `sn` y `mail`. Esta ejecución verifica el servidor y
el reenvío local; no comprueba el DNS del grupo ni el acceso desde otro equipo.
Resultado: [`validacion-commit-20261008.txt`](evidencias/ldap/validacion-commit-20261008.txt).
