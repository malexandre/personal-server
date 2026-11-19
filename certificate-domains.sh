#!/usr/bin/env bash
#
# The Let's Encrypt certificates of this server, sourced by init-letsencrypt.sh
# and expand-certificates.sh. Each entry is "<lineage-name> <domain> [more
# domains...]". The lineage name is the directory under /etc/letsencrypt/live
# and must match the ssl_certificate paths in nginx.conf.
#
# To serve a new domain: add it to a lineage here, add its `server` block to
# nginx.conf, deploy with ./update.sh, then run ./expand-certificates.sh.
CERTS=(
    "malexandre.fr malexandre.fr www.malexandre.fr brewer.malexandre.fr deck.malexandre.fr"
    "sfbdb.com sfbdb.com www.sfbdb.com"
)
