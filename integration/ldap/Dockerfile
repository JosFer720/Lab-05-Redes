FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN printf '%s\n' 'slapd slapd/no_configuration boolean false' 'slapd slapd/domain string aerolinea.redes.test' 'slapd shared/organization string Aerolinea' 'slapd slapd/password1 password AdminLDAP' 'slapd slapd/password2 password AdminLDAP' 'slapd slapd/backend select MDB' | debconf-set-selections \
 && apt-get update && apt-get install -y --no-install-recommends slapd ldap-utils && rm -rf /var/lib/apt/lists/*
COPY users.ldif /opt/users.ldif
COPY entrypoint.sh /usr/local/bin/ldap-entrypoint
RUN chmod 0755 /usr/local/bin/ldap-entrypoint
ENTRYPOINT ["/usr/local/bin/ldap-entrypoint"]
