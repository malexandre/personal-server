#!/usr/bin/env bash
#
# First-run bootstrap for a fresh server. Creates the on-disk directories the
# bind-mounted volumes need, fetches app sources, issues TLS certificates, then
# builds and starts the whole stack. Run ./update.sh for subsequent deploys.
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

# Clone the TeamBrewer source used to build its containers.
if [ -d teambrewer/.git ]; then
    (cd teambrewer && git fetch origin main && git reset --hard origin/main)
else
    git clone --branch main https://github.com/malexandre/teambrewer.git teambrewer
fi

# Issue Let's Encrypt certificates (first run only; renewals are automatic).
./init-letsencrypt.sh

# Build images one service at a time. Building all in parallel (the default of
# `up --build`) runs several Node installs at once and can exhaust RAM on a small
# VPS. Keep this list in sync with the services that have a `build:` section.
for service in teambrewer-api teambrewer-web blog sfb-db; do
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
