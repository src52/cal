# Fetch the latest published, non-prerelease Baikal distribution ZIP.
# Rebuild with --no-cache to re-resolve releases/latest.
FROM alpine:3.22 AS download
RUN apk add --no-cache ca-certificates curl jq unzip
WORKDIR /tmp/baikal
RUN set -eux; \
    release_json="$(curl -fsSL --retry 3 https://api.github.com/repos/sabre-io/Baikal/releases/latest)"; \
    version="$(printf '%s' "$release_json" | jq -er '.tag_name')"; \
    asset_url="$(printf '%s' "$release_json" | jq -er --arg name "baikal-${version}.zip" '.assets[] | select(.name == $name) | .browser_download_url')"; \
    echo "Downloading official Baikal release $version"; \
    curl -fL --retry 3 "$asset_url" -o /tmp/baikal.zip; \
    unzip -q /tmp/baikal.zip -d /tmp/baikal; \
    test -f /tmp/baikal/baikal/html/index.php; \
    test -f /tmp/baikal/baikal/html/dav.php

# Alpine 3.22 packages PHP 8.4. All services run within the same container.
FROM alpine:3.22
RUN apk add --no-cache \
    nginx ca-certificates \
    php84 php84-fpm php84-curl php84-mbstring \
    php84-pdo php84-pdo_mysql php84-pdo_pgsql php84-pdo_sqlite \
    php84-sqlite3 php84-xml php84-dom php84-ctype \
    php84-session php84-openssl php84-fileinfo php84-intl \
    php84-tokenizer php84-phar php84-iconv \
    && mkdir -p /run/nginx /var/www/baikal \
    && sed -i 's/^user = .*/user = nginx/' /etc/php84/php-fpm.d/www.conf \
    && sed -i 's/^group = .*/group = nginx/' /etc/php84/php-fpm.d/www.conf \
    && sed -i 's|^listen = .*|listen = 127.0.0.1:9000|' /etc/php84/php-fpm.d/www.conf \
    && printf '\nexpose_php = Off\n' > /etc/php84/conf.d/99-security.ini
COPY --from=download --chown=nginx:nginx /tmp/baikal/baikal/ /var/www/baikal/
COPY nginx.conf /etc/nginx/http.d/default.conf
COPY entrypoint.sh /usr/local/bin/baikal-entrypoint
RUN chmod +x /usr/local/bin/baikal-entrypoint
WORKDIR /var/www/baikal
EXPOSE 80
ENTRYPOINT ["/usr/local/bin/baikal-entrypoint"]
