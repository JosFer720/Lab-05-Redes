FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN echo 'postfix postfix/mailname string aerolinea.redes.test' | debconf-set-selections \
 && echo 'postfix postfix/main_mailer_type select Internet Site' | debconf-set-selections \
 && apt-get update && apt-get install -y --no-install-recommends postfix postfix-ldap dovecot-core dovecot-imapd dovecot-ldap dovecot-lmtpd && rm -rf /var/lib/apt/lists/*
COPY mail/config/ /opt/mail-config/
COPY integration/mail/entrypoint.sh /usr/local/bin/mail-entrypoint
RUN groupadd -g 5000 vmail && useradd -u 5000 -g vmail -d /var/mail/vhosts -s /usr/sbin/nologin vmail \
 && install -d -o vmail -g vmail -m 0750 /var/mail/vhosts/aerolinea.redes.test \
 && sed 's/DOMAIN/aerolinea.redes.test/g' /opt/mail-config/postfix/main.cf > /etc/postfix/main.cf \
 && sed -e 's/DOMAIN/aerolinea.redes.test/g' -e 's/BASE_DN/dc=aerolinea,dc=redes,dc=test/g' /opt/mail-config/postfix/ldap-virtual-mailbox.cf > /etc/postfix/ldap-virtual-mailbox.cf \
 && cat /opt/mail-config/postfix/submission.master.cf >> /etc/postfix/master.cf \
 && sed 's/DOMAIN/aerolinea.redes.test/g' /opt/mail-config/dovecot/10-auth.conf > /etc/dovecot/conf.d/10-auth.conf \
 && sed 's/DOMAIN/aerolinea.redes.test/g' /opt/mail-config/dovecot/auth-ldap.conf.ext > /etc/dovecot/conf.d/auth-ldap.conf.ext \
 && sed -e 's/DOMAIN/aerolinea.redes.test/g' -e 's/BASE_DN/dc=aerolinea,dc=redes,dc=test/g' /opt/mail-config/dovecot/dovecot-ldap.conf.ext > /etc/dovecot/dovecot-ldap.conf.ext \
 && sed 's/DOMAIN/aerolinea.redes.test/g' /opt/mail-config/dovecot/99-aerolinea.conf > /etc/dovecot/conf.d/99-aerolinea.conf \
 && chown root:postfix /etc/postfix/ldap-virtual-mailbox.cf && chmod 0640 /etc/postfix/ldap-virtual-mailbox.cf \
 && chown root:dovecot /etc/dovecot/dovecot-ldap.conf.ext && chmod 0640 /etc/dovecot/dovecot-ldap.conf.ext \
 && chmod 0755 /usr/local/bin/mail-entrypoint && postfix check && doveconf -n >/dev/null
ENTRYPOINT ["/usr/local/bin/mail-entrypoint"]
