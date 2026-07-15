#!/usr/bin/env bash
#
# One-time Let's Encrypt bootstrap. Nginx cannot start referencing certificates
# that do not exist yet, so this script: (1) drops a temporary self-signed cert
# for each lineage, (2) starts the `web` container, (3) deletes the dummies and
# requests the real certificates via the ACME HTTP-01 (webroot) challenge, then
# (4) reloads Nginx. Run it ONCE on first deploy. Renewals afterwards are handled
# automatically by the `certbot` service.
#
# Prerequisites: DNS A-records for every domain below must already point at this
# VPS, and ports 80/443 must be open.
#
# Usage:
#   EMAIL=you@example.com ./init-letsencrypt.sh
#   STAGING=1 EMAIL=you@example.com ./init-letsencrypt.sh   # test against LE staging
#
# Note: the `certbot` compose service overrides its entrypoint with a renewal
# loop, so every one-off command below overrides `--entrypoint` back to a real
# binary (`sh` or `certbot`).
set -euo pipefail

cd "$(dirname "$0")"

# Contact email for Let's Encrypt (expiry/renewal notices). Required — pass it in:
#   EMAIL=you@example.com ./init-letsencrypt.sh
EMAIL="${EMAIL:?set EMAIL=you@example.com, the certificate contact address}"
# Set STAGING=1 to hit Let's Encrypt's staging endpoint (untrusted certs, but no
# rate limits) while validating the setup. Leave unset for real certificates.
STAGING="${STAGING:-0}"

COMPOSE="docker compose"

# Certificate lineages: "<lineage-name> <domain> [more domains...]". The lineage
# name is the directory under /etc/letsencrypt/live and must match nginx.conf.
CERTS=(
    "malexandre.fr malexandre.fr www.malexandre.fr brewer.malexandre.fr"
    "sfbdb.com sfbdb.com www.sfbdb.com"
)

echo "### Creating temporary self-signed certificates ..."
for entry in "${CERTS[@]}"; do
    read -r name _ <<< "$entry"
    live_path="/etc/letsencrypt/live/$name"
    $COMPOSE run --rm --entrypoint sh certbot -c "\
        mkdir -p '$live_path' && \
        openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
            -keyout '$live_path/privkey.pem' \
            -out '$live_path/fullchain.pem' \
            -subj '/CN=localhost'"
done

echo "### Starting nginx ..."
$COMPOSE up -d web

echo "### Deleting temporary certificates ..."
for entry in "${CERTS[@]}"; do
    read -r name _ <<< "$entry"
    $COMPOSE run --rm --entrypoint sh certbot -c "\
        rm -rf '/etc/letsencrypt/live/$name' \
            '/etc/letsencrypt/archive/$name' \
            '/etc/letsencrypt/renewal/$name.conf'"
done

# Build the shared certbot flags.
staging_flag=""
if [ "$STAGING" != "0" ]; then
    staging_flag="--staging"
fi

echo "### Requesting Let's Encrypt certificates ..."
for entry in "${CERTS[@]}"; do
    # First token is the lineage name; the rest are the domains for this cert.
    read -r name domains <<< "$entry"
    domain_args=""
    for domain in $domains; do
        domain_args="$domain_args -d $domain"
    done
    # shellcheck disable=SC2086
    $COMPOSE run --rm --entrypoint certbot certbot \
        certonly --webroot -w /var/www/certbot \
        $staging_flag \
        --cert-name "$name" \
        $domain_args \
        --email "$EMAIL" \
        --agree-tos --no-eff-email \
        --non-interactive --keep-until-expiring
done

echo "### Reloading nginx ..."
$COMPOSE exec web nginx -s reload

echo "### Done. Certificates issued for:"
for entry in "${CERTS[@]}"; do
    read -r name _ <<< "$entry"
    echo "  - $name"
done
