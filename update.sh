#!/usr/bin/env bash
#
# Redeploy: pull this repo, refresh app sources, rebuild and restart the stack.
# Certificates and the TeamBrewer database volume are left untouched.
set -euo pipefail

cd "$(dirname "$0")"

git pull --rebase

# Directories backing bind-mounted volumes / static roots.
mkdir -p www/blog www/sfbdb www/staticfiles

# Refresh the mbp15 static page.
wget -O www/staticfiles/mbp15.html \
    https://raw.githubusercontent.com/malexandre/mbp-1.5-pool-generator/master/index.html

# Update the TeamBrewer source to the latest main.
if [ -d teambrewer/.git ]; then
    (cd teambrewer && git fetch origin main && git reset --hard origin/main)
else
    git clone --branch main https://github.com/malexandre/teambrewer.git teambrewer
fi

# Rebuild images one service at a time (parallel builds can exhaust RAM on a small
# VPS). Keep this list in sync with the services that have a `build:` section.
# The TeamBrewer API applies pending DB migrations on boot.
for service in teambrewer-api teambrewer-web blog sfb-db; do
    echo "==> Building $service ..."
    docker compose build "$service"
done

# Restart the whole stack.
docker compose up -d
