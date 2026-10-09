# Comparación de los repositorios del laboratorio

Repositorio de entrega: https://github.com/JosFer720/Lab-05-Redes
Base de entrega: `62a20a408dd508d9033ae34c0ed66df7f118fd1c`.
Repositorio de pruebas: https://github.com/JosFer720/lab05-redes-prueba
Referencia comparada: `4169e863d849882392050b5d9f4cba3f6b9f480d`.
Base común: `67286227c1d55820cbaa827dffe8f6f808a16156`.

La integración toma los archivos pendientes del repositorio de pruebas y
conserva los cambios posteriores del equipo en el repositorio de entrega.
Por eso las carpetas completas no son idénticas: se mantienen la entrega de
OpenLDAP, sus usuarios y evidencias, la configuración de correo, los cambios
FTP y los scripts de arranque de cada servicio.

## BIND DNS

Se recuperó la implementación de Ian de la rama local respaldada:
configuración BIND9, zona con SOA/NS/MX y cinco registros A, instalador,
actualización de IPs y serial, generación de tabla, pruebas UDP/TCP,
recolección de evidencias y herramientas de WSL. El instalador acepta también
las variables de direcciones del repositorio de pruebas. Las direcciones
`10.223.12.x` son las documentadas el 7 de octubre de 2026; se deben actualizar
al cambiar de red.

## Archivos pendientes integrados

- Suite `client/tests/test-all.sh` y documentación del cliente.
- Diagrama de arquitectura y guía de puesta en marcha.
- Variante Docker del servicio FTP y entorno de integración de los cinco servicios.
- Correcciones web del repositorio de pruebas, incluido el uso de `import.meta.dirname`.
- Plantilla `shared/lab.example.env`, referenciada por la documentación pero ausente en ambos repositorios.
- Reglas LF para que los scripts Bash funcionen al clonar desde Windows.

El entorno Docker se corrigió para construir desde un clon limpio: bases
Ubuntu públicas, compilación del sitio dentro de la imagen, construcción de
FTP sin imagen local previa, comprobaciones de disponibilidad y una zona
esperada específica para el cliente de integración.

## Cambios del equipo conservados

Se verificaron los 74 archivos modificados o añadidos en la entrega desde la
base común, excepto el README principal, al que se agregaron instrucciones
sin quitar las secciones del equipo. Su contenido se conserva; las reglas
LF solo corrigen los terminadores del archivo en Windows. No se restauran
carpetas eliminadas por el equipo ni se reemplazan sus evidencias LDAP.

## Validación

Las evidencias DNS en `docs/evidencias/dns/` corresponden a pruebas locales
reales en la distro `lab5-ns1` el 9 de octubre de 2026. Ver
`docs/evidencias/dns/validacion-local-20261009.txt`. Estas pruebas comprueban
BIND local; la conectividad hacia las VMs de los compañeros debe verificarse
en la red que utilice el grupo.

La suite Docker completa aprobó 39 comprobaciones: DNS (11), LDAP (4),
web (9), correo (6) y FTP (9). Se construyeron las seis imágenes desde el
repositorio y todos los servicios quedaron disponibles antes de iniciar las
pruebas. La salida está en `docs/evidencias/integration/validacion-20261009.txt`.
El sitio compiló con `npm run build`; `npm run lint` terminó con tres avisos
heredados sobre Fast Refresh y sin errores. `npm audit --omit=dev` informó
cero vulnerabilidades en las dependencias de producción.
