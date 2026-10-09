FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends bind9 bind9-utils dnsutils && rm -rf /var/lib/apt/lists/*
COPY named.conf.options /etc/bind/named.conf.options
COPY named.conf.local /etc/bind/named.conf.local
COPY db.aerolinea.redes.test /etc/bind/db.aerolinea.redes.test
RUN named-checkconf && named-checkzone aerolinea.redes.test /etc/bind/db.aerolinea.redes.test
CMD ["/usr/sbin/named", "-u", "bind", "-4", "-n", "2", "-g", "-c", "/etc/bind/named.conf"]
