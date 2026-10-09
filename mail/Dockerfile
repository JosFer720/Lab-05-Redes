FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    echo "postfix postfix/mailname string aerolinea.redes.test" | debconf-set-selections; \
    echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      dovecot-core \
      dovecot-imapd \
      dovecot-ldap \
      dovecot-lmtpd \
      ldap-utils \
      netcat-openbsd \
      postfix \
      postfix-ldap \
      supervisor; \
    rm -rf /var/lib/apt/lists/*

COPY config /opt/mail-templates
COPY docker/entrypoint.sh /usr/local/bin/mail-entrypoint
COPY docker/healthcheck.sh /usr/local/bin/mail-healthcheck
COPY docker/supervisord.conf /etc/supervisor/conf.d/mail.conf

RUN chmod 0755 /usr/local/bin/mail-entrypoint /usr/local/bin/mail-healthcheck

VOLUME ["/var/mail/vhosts"]
EXPOSE 25 143 587

HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=6 \
  CMD ["/usr/local/bin/mail-healthcheck"]

ENTRYPOINT ["/usr/local/bin/mail-entrypoint"]
