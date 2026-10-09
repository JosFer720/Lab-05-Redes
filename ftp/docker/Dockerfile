FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends vsftpd curl \
    && rm -rf /var/lib/apt/lists/*

COPY vsftpd.conf /etc/vsftpd.conf
COPY entrypoint.sh /usr/local/bin/ftp-entrypoint

RUN chmod 0755 /usr/local/bin/ftp-entrypoint

EXPOSE 21 40000-40010

ENTRYPOINT ["/usr/local/bin/ftp-entrypoint"]
