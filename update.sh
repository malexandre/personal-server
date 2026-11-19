#!/usr/bin/env bash
#
# Redeploy: pull this repo, refresh the static pages, pull every pre-built image
# (Nginx, Certbot, Postgres, TeamBrewer), rebuild the local static-site images,
# and restart the stack. Certificates and the TeamBrewer database volume are
# left untouched.
set -euo pipefail

cd "$(dirname "$0")"

git pull --rebase

# Directories backing bind-mounted volumes / static roots.
mkdir -p www/blog www/sfbdb www/staticfiles www/deck

# Refresh the single-file static pages (mbp15, FaB Deck Image).
source ./fetch-static-pages.sh

# Pull every image that is not built here, so security releases of Nginx,
# Certbot and Postgres are picked up on each deploy: `docker compose up` alone
# keeps whatever image is already on the box. The Postgres tag stays on major
# version 17, so only minor releases arrive and the data volume stays valid.
# The TeamBrewer images come from GHCR (built in CI): bump their version via
# TEAMBREWER_VERSION in .env. The API applies pending DB migrations on boot. If
# the packages are private, `docker login ghcr.io` first.
docker compose pull web certbot teambrewer-postgres teambrewer-api teambrewer-web

# Build the remaining local images one at a time (parallel builds can exhaust RAM
# on a small VPS). Keep this list in sync with the services that have a `build:`
# section — only the static-site builders are built here now.
for service in blog sfb-db; do
    echo "==> Building $service ..."
    docker compose build "$service"
done

# Restart the whole stack. Containers whose image or configuration changed are
# recreated; the others keep running.
docker compose up -d

# Free the disk space of the images that were just replaced.
docker image prune -f
