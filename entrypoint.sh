#!/bin/sh
set -eu

# Bind-mounted directories survive image upgrades. Ensure the PHP worker
# can read and write configuration and SQLite databases, like ckulka's image.
mkdir -p /var/www/baikal/config /var/www/baikal/Specific
if [ "${BAIKAL_SKIP_CHOWN:-}" != "1" ]; then
  chown -R nginx:nginx /var/www/baikal/config /var/www/baikal/Specific
fi

# Validate configurations before launching long-running services.
php-fpm84 -t
nginx -t
php-fpm84 -D
exec nginx -g 'daemon off;'
