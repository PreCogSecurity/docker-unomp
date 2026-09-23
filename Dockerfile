# syntax=docker/dockerfile:1

# docker-unomp — UNOMP mining pool portal image.
#
# Reproducibility: the base image is pinned by digest (linux/amd64) and the
# upstream UNOMP checkout is pinned by commit SHA, so repeated builds are
# deterministic. Dependabot tracks base-image updates; bump the checkout SHA
# deliberately when you want newer UNOMP code.

FROM node:0.10@sha256:c32b4d56f05c69df6e87d06bf7d5f6a5c6a0e7bcdb8e5ffab0e7a1853a90008f

# bignum (a native module used for difficulty math) is compiled from source
# by `npm update`, so the image needs the C/C++ toolchain, the OpenSSL
# headers, and Python (node-gyp). The packages are intentionally not pinned:
# the node:0.10 base image is an EOL Debian release whose apt repositories
# are frozen, so exact version pinning would make the build fragile. DL3008
# stays disabled for this reason (see .hadolint.yaml).
#
# The node:0.10 base image is Debian jessie, which reached end-of-life and
# was removed from the regular mirrors (deb.debian.org / security.debian.org
# now return 404, breaking `apt-get update`). Point apt at the Debian
# archive instead, which keeps serving archived releases, and skip the
# Valid-Until check because the archived Release files are old. The archive
# repos are marked [trusted=yes] because the GPG keys that signed their
# Release files have expired: apt would otherwise treat every package as
# unauthenticated and abort the install under -y with "E: There are problems
# and -y was used without --force-yes".
RUN set -eux; \
    echo "deb [trusted=yes] http://archive.debian.org/debian/ jessie main" > /etc/apt/sources.list; \
    echo "deb [trusted=yes] http://archive.debian.org/debian-security/ jessie/updates main" >> /etc/apt/sources.list; \
    rm -f /etc/apt/sources.list.d/*; \
    apt-get -o Acquire::Check-Valid-Until=false update && apt-get install -y --no-install-recommends \
        build-essential libssl-dev python \
        && rm -rf /var/lib/apt/lists/*

# Create app directory
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# Pin the upstream UNOMP source by commit SHA for reproducible builds.
# Bump deliberately: https://github.com/UNOMP/unified-node-open-mining-portal
ARG UNOMP_COMMIT=72f93ea3f4f52164f71b6f27a630e977edee8d44
RUN git clone https://github.com/UNOMP/unified-node-open-mining-portal.git unomp
WORKDIR /usr/src/app/unomp
# Check out the pinned commit and install dependencies (the upstream install
# command, see the upstream README). The upstream package.json references
# some dependencies with `git://` URLs; GitHub disabled the unauthenticated
# git:// protocol, so rewrite those URLs to https:// for git.
RUN git config --global url."https://github.com/".insteadOf "git://github.com/" \
    && git checkout "$UNOMP_COMMIT" && npm update

# Generate config.json from the upstream example on first start so the
# container runs out of the box (see docker-entrypoint.sh).
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 80 3008 3032 3256
CMD [ "node", "init.js" ]
