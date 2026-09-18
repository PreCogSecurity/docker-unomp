# syntax=docker/dockerfile:1

# docker-unomp — UNOMP mining pool portal image.
#
# Reproducibility: the base image is pinned by digest (linux/amd64) and the
# upstream UNOMP checkout is pinned by commit SHA, so repeated builds are
# deterministic. Dependabot tracks base-image updates; bump the checkout SHA
# deliberately when you want newer UNOMP code.

FROM node:0.10@sha256:c32b4d56f05c69df6e87d06bf7d5f6a5c6a0e7bcdb8e5ffab0e7a1853a90008f

# The native build dependencies line is intentionally commented out: the
# prebuilt binaries fetched by `npm update` do not require them. If you
# uncomment it for source builds, pin the packages and re-enable the
# corresponding hadolint rules (see .hadolint.yaml).
# RUN apt-get update && apt-get install -y --no-install-recommends build-essential libssl-dev \
#         && rm -rf /var/lib/apt/lists/*

# Create app directory
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# Pin the upstream UNOMP source by commit SHA for reproducible builds.
# Bump deliberately: https://github.com/UNOMP/unified-node-open-mining-portal
ARG UNOMP_COMMIT=72f93ea3f4f52164f71b6f27a630e977edee8d44
RUN git clone https://github.com/UNOMP/unified-node-open-mining-portal.git unomp
WORKDIR /usr/src/app/unomp
# Check out the pinned commit and install dependencies (the upstream install
# command, see the upstream README).
RUN git checkout "$UNOMP_COMMIT" && npm update

# Generate config.json from the upstream example on first start so the
# container runs out of the box (see docker-entrypoint.sh).
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 80 3008 3032 3256
CMD [ "node", "init.js" ]
