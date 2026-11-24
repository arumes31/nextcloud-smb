# syntax=docker/dockerfile:1.20

ARG NEXTCLOUD_IMAGE=nextcloud:production

FROM ${NEXTCLOUD_IMAGE} AS extension-builder

ARG SMBCLIENT_EXTENSION_VERSION=1.2.0dev

# Debian packages stay unpinned: security updates remove pinned versions from the mirror.
# hadolint ignore=DL3008
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends libsmbclient-dev; \
    pecl install "channel://pecl.php.net/smbclient-${SMBCLIENT_EXTENSION_VERSION}"; \
    docker-php-ext-enable smbclient; \
    php --ri smbclient; \
    rm -rf /var/lib/apt/lists/* /tmp/pear

FROM ${NEXTCLOUD_IMAGE}

LABEL org.opencontainers.image.source="https://github.com/arumes31/nextcloud-smb" \
      org.opencontainers.image.description="Hardened Nextcloud image with SMB support" \
      org.opencontainers.image.licenses="MIT"

# Take every Debian update, even before upstream rebuilds; CI blocks any fixable OS CVE left.
# A new APT_REFRESH value invalidates the cached layer so the upgrade really runs.
ARG APT_REFRESH=
# hadolint ignore=DL3008
RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y --no-install-recommends; \
    apt-get install -y --no-install-recommends smbclient; \
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
