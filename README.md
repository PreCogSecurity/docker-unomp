# docker-unomp

Docker image for [UNOMP](https://github.com/UNOMP/unified-node-open-mining-portal)
(the Unified Node Open Mining Portal) — an efficient, scalable cryptocurrency
mining pool server written in Node.js. The image clones the pinned UNOMP
source, installs its dependencies, and starts the portal with `node init.js`.

> **Note:** UNOMP is beta software and is no longer actively maintained
> upstream. It requires a Redis server and one or more coin daemons to
> function. See the upstream
> [README](https://github.com/UNOMP/unified-node-open-mining-portal) for
> configuration details.

## Requirements

- Docker (with BuildKit) — tested with Docker 29.x
- A running [Redis](https://redis.io/) server (v2.6+) for share/payment data
- Coin daemon(s) with RPC enabled for the coin(s) you want to mine

## Build

```sh
docker build -t unomp .
```

The base image and the upstream UNOMP checkout are pinned (base image digest
and git commit SHA), so repeated builds are reproducible. The image installs
the native build toolchain (`build-essential`, `libssl-dev`, `python`) needed
to compile the `bignum` native module from source during `npm update`.
Dependabot tracks base-image updates; bump the `UNOMP_COMMIT` build arg in the
`Dockerfile` when you deliberately want newer UNOMP code.

## Run

### With Docker Compose (recommended)

The included `docker-compose.yml` starts UNOMP together with a Redis server.
On first start the container entrypoint generates `config.json` from the
upstream example, pointing the redis section at the `redis` service, so the
stack runs out of the box:

```sh
docker compose up -d
docker compose logs -f unomp
```

To use your own configuration, create `./config.json` first (see
[Configuration](#configuration)), then uncomment the `volumes` block under
the `unomp` service in `docker-compose.yml`.

### With plain Docker

```sh
docker run -d --name unomp \
  -p 80:80 \
  -p 3008:3008 \
  -p 3032:3032 \
  -p 3256:3256 \
  -v "$PWD/config.json:/usr/src/app/unomp/config.json:ro" \
  unomp
```

Without a mounted `config.json`, the entrypoint generates one from the
upstream example with the redis host set to `redis` — which only resolves
inside the Compose network. For standalone runs, mount your own `config.json`
as shown above.

## Configuration

UNOMP reads `config.json` from its working directory
(`/usr/src/app/unomp`). The image ships with the upstream example config and
generates a working `config.json` from it on first start (redis host
`redis`); mount your own `config.json` (and `pool_configs/*.json`,
`coins/*.json`) as a read-only volume to override it, as shown above.

Copy the upstream example and edit it before first run:

```sh
docker run --rm unomp cat /usr/src/app/unomp/config.json.example > config.json
```

### Ports

| Port | Purpose (UNOMP defaults)                          |
|------|---------------------------------------------------|
| 80   | Website (upstream example binds 80 internally)    |
| 3008 | UNOMP API                                         |
| 3032 | Stratum miner port (diff 32)                      |
| 3256 | Stratum miner port (diff 256)                     |

The actual ports UNOMP binds are defined in `config.json`, not by `EXPOSE`;
adjust the port mappings in `docker-compose.yml` or your `docker run` command
to match your configuration.

### Environment variables

The image itself defines no environment variables — all runtime behavior is
driven by `config.json`. The Compose file supports the following overrides
(see `.env.example`):

| Variable            | Default | Description                                    |
|---------------------|---------|------------------------------------------------|
| `UNOMP_IMAGE_TAG`   | `latest`| Image tag to run                               |
| `UNOMP_HTTP_PORT`   | `80`    | Host port for the website                      |
| `UNOMP_API_PORT`    | `3008`  | Host port for the API                          |
| `UNOMP_STRATUM_PORT_1` | `3032` | Host port for the first stratum port         |
| `UNOMP_STRATUM_PORT_2` | `3256` | Host port for the second stratum port        |
| `REDIS_PORT`        | `6379`  | Host port for the bundled Redis server         |

## Testing

`tests/smoke_test.sh` builds the image, starts a container, waits for the
UNOMP process to come up, and asserts the expected process is running and the
exposed ports are listening. It exits non-zero on any failure:

```sh
bash tests/smoke_test.sh
```

The same script runs in CI (`.github/workflows/ci.yml`) on every push and
pull request, after a `hadolint` lint pass over the `Dockerfile`.

## CI

`.github/workflows/ci.yml` runs on every push and pull request:

1. **lint** — `hadolint` over the `Dockerfile`
2. **build** — `docker build -t unomp:test .`
3. **test** — `tests/smoke_test.sh` against the built image
4. **scan** — `trivy` vulnerability scan (informational; the end-of-life
   `node:0.10` base image always reports CVEs, so the report is uploaded as
   an artifact for drift tracking rather than gating the pipeline)

## License

The Dockerfile and supporting files in this repository are provided as-is
without a license grant unless one is added. The bundled UNOMP software is
GPL-2.0; see the upstream repository for its license terms.
