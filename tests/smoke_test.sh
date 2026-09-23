#!/usr/bin/env bash
#
# Smoke test for the docker-unomp image.
#
# Builds the image (unless it already exists locally), starts a throwaway
# Redis container and the UNOMP container on a shared network, generates a
# config.json from the upstream example (pointing Redis at the companion
# container), then asserts:
#   1. the `node init.js` master process is running, and
#   2. the website port (80) is listening inside the container.
#
# Exits non-zero on any failure so it can gate CI.
#
# Usage:
#   bash tests/smoke_test.sh                 # builds unomp:test locally
#   UNOMP_IMAGE=unomp:test bash tests/smoke_test.sh

set -euo pipefail

IMAGE="${UNOMP_IMAGE:-unomp:test}"
NET="unomp-smoke-$$"
REDIS_CT="unomp-smoke-redis-$$"
UNOMP_CT="unomp-smoke-unomp-$$"
TIMEOUT="${SMOKE_TEST_TIMEOUT:-120}"
WORKDIR="$(mktemp -d)"

cleanup() {
    docker rm -f "$UNOMP_CT" >/dev/null 2>&1 || true
    docker rm -f "$REDIS_CT" >/dev/null 2>&1 || true
    docker network rm "$NET" >/dev/null 2>&1 || true
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "==> Image ${IMAGE} already present; skipping build"
else
    echo "==> Building image ${IMAGE}"
    docker build -t "$IMAGE" .
fi

echo "==> Creating network ${NET}"
docker network create "$NET"

echo "==> Starting Redis companion"
docker run -d --name "$REDIS_CT" --network "$NET" redis:6-alpine >/dev/null

echo "==> Generating config.json (redis -> ${REDIS_CT})"
docker run --rm -v "$WORKDIR:/tmp/cfg" "$IMAGE" node -e "
var fs = require('fs');
var c = fs.readFileSync('/usr/src/app/unomp/config.json.example', 'utf8');
c = c.replace(/\"host\": \"127\.0\.0\.1\"/g, '\"host\": \"${REDIS_CT}\"');
fs.writeFileSync('/tmp/cfg/config.json', c);
"

echo "==> Starting UNOMP container"
docker run -d --name "$UNOMP_CT" --network "$NET" \
    -v "$WORKDIR/config.json:/usr/src/app/unomp/config.json:ro" \
    "$IMAGE" >/dev/null

echo "==> Waiting up to ${TIMEOUT}s for UNOMP to come up"
deadline=$(( $(date +%s) + TIMEOUT ))
master_up=0
website_up=0
while [ "$(date +%s)" -lt "$deadline" ]; do
    if [ "$master_up" -eq 0 ] && docker top "$UNOMP_CT" 2>/dev/null | grep -q "node init.js"; then
        echo "    master process 'node init.js' is running"
        master_up=1
    fi
    if [ "$website_up" -eq 0 ] && docker exec "$UNOMP_CT" node -e \
        "require('net').connect(80, '127.0.0.1', function(){process.exit(0)}).on('error', function(){process.exit(1)})" \
        >/dev/null 2>&1; then
        echo "    website port 80 is listening"
        website_up=1
    fi
    [ "$master_up" -eq 1 ] && [ "$website_up" -eq 1 ] && break
    sleep 2
done

if [ "$master_up" -ne 1 ] || [ "$website_up" -ne 1 ]; then
    echo "FAIL: master_up=${master_up} website_up=${website_up}" >&2
    echo "--- container logs ---" >&2
    docker logs "$UNOMP_CT" 2>&1 | tail -n 40 || true
    exit 1
fi

echo "==> Confirming container is still running"
state="$(docker inspect -f '{{.State.Running}}' "$UNOMP_CT")"
if [ "$state" != "true" ]; then
    echo "FAIL: container is not running (state=${state})" >&2
    exit 1
fi

echo "PASS: UNOMP container is up, master process running, website port 80 responding."
