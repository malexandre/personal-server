#!/usr/bin/env bash
#
# Downloads the single-file static pages served straight from their GitHub
# repository, sourced by launch.sh and update.sh. Each page is downloaded to a
# temporary file first, so a failed download keeps the page that is being
# served instead of leaving an empty file.
download_page() {
    local url="$1"
    local destination="$2"
    mkdir -p "$(dirname "$destination")"
    wget -O "$destination.download" "$url"
    mv "$destination.download" "$destination"
}

# mbp15, served at malexandre.fr/mbp15.
download_page \
    https://raw.githubusercontent.com/malexandre/mbp-1.5-pool-generator/master/index.html \
    www/staticfiles/mbp15.html

# FaB Deck Image, served at deck.malexandre.fr.
download_page \
    https://raw.githubusercontent.com/malexandre/fab-deck-image/main/index.html \
    www/deck/index.html
