# Servidor web: Apache con login LDAP

Esta implementación proporciona:

- sitio `http://www.aerolinea.redes.test` con portada del grupo;
- área protegida en `/privado/` que exige usuario LDAP;
- formulario de login propio con `mod_auth_form`;
- validación contra `ou=People,dc=aerolinea,dc=redes,dc=test` con `mod_authnz_ldap`;
- sesión en cookie cifrada `HttpOnly` con `mod_session_crypto`, válida 30 minutos;
- logs propios en `/var/log/apache2/aerolinea-*.log`.

## Sitio

El sitio está en `site/` y usa Vite, React, Tailwind y componentes shadcn del
registro de [neobrutalism.com](https://neobrutalism.com). Se compila en
cualquier equipo con Node.js:

```bash
cd site
npm install
npm run build
```

El resultado queda en `site/dist/` y es lo que el instalador copia a
`/var/www/aerolinea`. Los integrantes se editan en `site/src/data/grupo.ts`.

## Despliegue en Ubuntu 24.04

Copiar el directorio `web/` con `site/dist/` ya compilado a la VM y ejecutar:

```bash
sudo ./scripts/install.sh
sudo ./scripts/verify-local.sh
```

El instalador habilita los módulos necesarios, genera la frase de cifrado de
sesión en `/etc/apache2/aerolinea-session.key` si no existe y reemplaza el
sitio por defecto. Puede repetirse para publicar una nueva versión del sitio.
El script no toca UFW. Si ya está activo:

```bash
sudo ufw allow 80/tcp
```

La búsqueda en LDAP es anónima, por lo que OpenLDAP debe permitir leer
`uid`, `cn` y `mail` en `ou=People`. La caché de LDAP está deshabilitada para
que cada acceso se valide contra el servidor.

## Flujo de autenticación

1. `/privado/` sin sesión redirige a `/login/`.
2. El formulario envía `httpd_username` y `httpd_password` a `/dologin`.
3. Apache busca el `uid` en LDAP y hace bind con la contraseña recibida.
4. Si es válida, crea la sesión y redirige a `/privado/`. Si no, redirige a
   `/login/?error=1` y registra el rechazo en `aerolinea-error.log`.
5. `/privado/usuario.json` usa SSI para mostrar `uid`, `cn` y `mail`
   devueltos por LDAP.
6. `/logout` elimina la sesión.

## Pruebas

Desde el cliente, con DNS apuntando a `ns1`:

```bash
WEB_USER='usuario' WEB_PASSWORD='clave-ldap' ./client/tests/test-web.sh
```

Para WEB-05, detener LDAP con `sudo systemctl stop slapd`, intentar ingresar y
revisar el error con:

```bash
sudo tail -n 20 /var/log/apache2/aerolinea-error.log
```
