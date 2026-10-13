# syntax=docker/dockerfile:1.20

FROM nextcloud:production AS extension-builder

ARG SMBCLIENT_EXTENSION_VERSION=1.2.0dev
ARG SAMBA_VERSION=2:4.22.11+dfsg-0+deb13u1

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libsmbclient-dev="${SAMBA_VERSION}"; \
    pecl install "channel://pecl.php.net/smbclient-${SMBCLIENT_EXTENSION_VERSION}"; \
    docker-php-ext-enable smbclient; \
    php --ri smbclient; \
    rm -rf /var/lib/apt/lists/* /tmp/pear

FROM nextcloud:production

ARG SAMBA_VERSION=2:4.22.11+dfsg-0+deb13u1
ARG OPENSSL_VERSION=3.5.7-1~deb13u3
ARG LINUX_LIBC_DEV_VERSION=6.12.111-1

LABEL org.opencontainers.image.source="https://github.com/arumes31/nextcloud-smb" \
      org.opencontainers.image.description="Hardened Nextcloud image with SMB support" \
      org.opencontainers.image.licenses="MIT"

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libssl3t64="${OPENSSL_VERSION}" \
        linux-libc-dev="${LINUX_LIBC_DEV_VERSION}" \
        openssl="${OPENSSL_VERSION}" \
        openssl-provider-legacy="${OPENSSL_VERSION}" \
        smbclient="${SAMBA_VERSION}"; \
    sed -ri 's!^Listen 80$!Listen 8080!' /etc/apache2/ports.conf; \
    sed -ri 's!<VirtualHost \*:80>!<VirtualHost *:8080>!' /etc/apache2/sites-available/000-default.conf; \
    install -d -o www-data -g www-data \
        /var/lock/apache2 \
        /var/log/apache2 \
        /var/run/apache2 \
        /var/www/html; \
    chown -R www-data:www-data /var/www/html; \
    install -o www-data -g www-data -m 0600 /dev/null \
        /usr/local/etc/php/conf.d/redis-session.ini; \
    rm -rf /var/lib/apt/lists/*

COPY --from=extension-builder /usr/local/etc/php/conf.d/docker-php-ext-smbclient.ini /usr/local/etc/php/conf.d/docker-php-ext-smbclient.ini
COPY --from=extension-builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/

USER 33:33
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD ["php", "-r", "$s=@fsockopen('127.0.0.1',8080,$e,$m,2); exit($s ? 0 : 1);"]
