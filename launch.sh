#!/usr/bin/env bash
#
# First-run bootstrap for a fresh server. Creates the on-disk directories the
# bind-mounted volumes need, issues TLS certificates, pulls the pre-built
# TeamBrewer images, builds the local static sites, and starts the stack. Run
# ./update.sh for subsequent deploys.
#
# Prerequisites: a root .env exists (see README.md), DNS points at this host, and
# ports 80/443 are open.
set -euo pipefail

cd "$(dirname "$0")"

# Directories backing bind-mounted volumes / static roots must exist before the
# containers start (the sfbdb volume is a bind mount to ./www/sfbdb).
mkdir -p www/blog www/sfbdb www/staticfiles

# Static page served at /mbp15.
wget -O www/staticfiles/mbp15.html \
    https://raw.githubusercontent.com/malexandre/mbp-1.5-pool-generator/master/index.html

# Issue Let's Encrypt certificates (first run only; renewals are automatic).
./init-letsencrypt.sh

# Pull the pre-built TeamBrewer images from GHCR (built in CI, not on this box).
# If the packages are private, run `docker login ghcr.io` first.
docker compose pull teambrewer-api teambrewer-web

# Build the local static-site images one at a time (parallel builds can exhaust
# RAM on a small VPS). Only the static builders are built here now.
for service in blog sfb-db; do
    echo "==> Building $service ..."
    docker compose build "$service"
done

# Start the whole stack (also pulls the image-only services: nginx, postgres, certbot).
docker compose up -d

cat <<'EOF'

Stack is up. To finish setting up TeamBrewer (first run only), seed reference
data, sync cards, and create the instance-admin — then open the printed setup
link to set the admin password and enable TOTP 2FA:

  docker compose exec -e SEED_ADMIN_USERNAME=admin -e SEED_ADMIN_DISPLAY_NAME="Admin" \
    teambrewer-api sh -c "node dist/main.seed.js && node dist/main.cli.js && node dist/main.bootstrap.js"

See README.md for details.
EOF
