#!/usr/bin/env bash
#
# Redeploy: pull this repo, pull the pre-built TeamBrewer images, rebuild the
# local static-site images, and restart the stack. Certificates and the
# TeamBrewer database volume are left untouched.
set -euo pipefail

cd "$(dirname "$0")"

git pull --rebase

# Directories backing bind-mounted volumes / static roots.
mkdir -p www/blog www/sfbdb www/staticfiles

# Refresh the mbp15 static page.
wget -O www/staticfiles/mbp15.html \
    https://raw.githubusercontent.com/malexandre/mbp-1.5-pool-generator/master/index.html

# Pull the pre-built TeamBrewer images from GHCR (built in CI, not on this box).
# Bump the version via TEAMBREWER_VERSION in .env. The API applies pending DB
# migrations on boot. If the packages are private, `docker login ghcr.io` first.
docker compose pull teambrewer-api teambrewer-web

# Build the remaining local images one at a time (parallel builds can exhaust RAM
# on a small VPS). Keep this list in sync with the services that have a `build:`
# section — only the static-site builders are built here now.
for service in blog sfb-db; do
    echo "==> Building $service ..."
    docker compose build "$service"
done

# Restart the whole stack.
docker compose up -d
