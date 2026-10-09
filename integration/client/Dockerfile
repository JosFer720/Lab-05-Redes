FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends dnsutils ldap-utils curl swaks ca-certificates && rm -rf /var/lib/apt/lists/*
COPY client/tests/ /tests/
COPY integration/dns/db.aerolinea.redes.test /zones/db.aerolinea.redes.test
RUN chmod 0755 /tests/*.sh
