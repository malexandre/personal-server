#!/usr/bin/env bash
#
# Brings the existing Let's Encrypt certificates in line with
# certificate-domains.sh, on a server that is already running. Run it after
# adding a domain to a lineage: the certificate is issued again with the full
# list of domains, then Nginx reloads to serve it. A lineage whose domains did
# not change is left alone.
#
# Prerequisites: the DNS A-record of the new domain points at this VPS, and the
# stack is up with the new nginx.conf (./update.sh), so the :80 vhost answers
# the ACME HTTP-01 challenge for it.
#
# Usage:
#   ./expand-certificates.sh
#   STAGING=1 ./expand-certificates.sh   # test against Let's Encrypt staging
set -euo pipefail

cd "$(dirname "$0")"

STAGING="${STAGING:-0}"

COMPOSE="docker compose"

# shellcheck source=certificate-domains.sh
source ./certificate-domains.sh

staging_flag=""
if [ "$STAGING" != "0" ]; then
    staging_flag="--staging"
fi

for entry in "${CERTS[@]}"; do
    # First token is the lineage name; the rest are the domains for this cert.
    read -r name domains <<< "$entry"
    domain_args=""
    for domain in $domains; do
        domain_args="$domain_args -d $domain"
    done
    echo "### Checking certificate $name ..."
    # The `certbot` compose service overrides its entrypoint with a renewal loop,
    # so the one-off command overrides `--entrypoint` back to the real binary.
    # shellcheck disable=SC2086
    $COMPOSE run --rm --entrypoint certbot certbot \
        certonly --webroot -w /var/www/certbot \
        $staging_flag \
        --cert-name "$name" \
        $domain_args \
        --expand \
        --non-interactive --keep-until-expiring
done

echo "### Reloading nginx ..."
$COMPOSE exec web nginx -s reload
