FROM node:24-bookworm-slim AS site
WORKDIR /site
COPY web/site/package.json web/site/package-lock.json ./
RUN npm ci
COPY web/site/ ./
RUN npm run build

FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends apache2 openssl && rm -rf /var/lib/apt/lists/* \
 && a2enmod ldap authnz_ldap auth_form request session session_cookie session_crypto include
COPY --from=site /site/dist/ /var/www/aerolinea/
COPY web/config/aerolinea.conf /etc/apache2/sites-available/aerolinea.conf
RUN openssl rand -base64 48 > /etc/apache2/aerolinea-session.key && chmod 0600 /etc/apache2/aerolinea-session.key \
 && a2dissite 000-default && a2ensite aerolinea && apache2ctl configtest
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
