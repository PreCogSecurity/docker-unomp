#!/bin/sh
#
# docker-unomp entrypoint: generate config.json from the upstream example on
# first start so the container runs out of the box.
#
# If a config.json is already present (e.g. mounted via docker-compose.yml or
# `docker run -v`), it is left untouched.
#
# The generated config points the redis section at host "redis", which is the
# service name used by the bundled docker-compose.yml. For plain `docker run`
# without a redis host named "redis", mount your own config.json instead
# (see README.md).

set -e

CONFIG=/usr/src/app/unomp/config.json
EXAMPLE=/usr/src/app/unomp/config.json.example

if [ ! -f "$CONFIG" ]; then
    echo "docker-unomp: $CONFIG not found; generating from example (redis host: redis)"
    sed 's/"host": "127\.0\.0\.1"/"host": "redis"/' "$EXAMPLE" > "$CONFIG"
fi

exec "$@"
