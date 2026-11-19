# personal-server

Config for my personal OVH VPS. A single Nginx container terminates TLS and
fronts every site; static sites are built by one-shot builder containers, and
[TeamBrewer](https://github.com/malexandre/teambrewer) runs as its own isolated
sub-stack.

## Hosted sites

| Domain | Service | What |
|--------|---------|------|
| `malexandre.fr`, `www.malexandre.fr` | `blog` | Hugo blog (built into `./www/blog`) |
| `sfbdb.com`, `www.sfbdb.com` | `sfb-db` | Static site (built into `./www/sfbdb`) |
| `brewer.malexandre.fr` | `teambrewer-*` | TeamBrewer (Postgres + NestJS API + Nginx) |
| `deck.malexandre.fr` | `web` | [FaB Deck Image](https://github.com/malexandre/fab-deck-image), one static page (downloaded into `./www/deck`) |

Every site is HTTPS only: port 80 answers the Let's Encrypt challenge and redirects
the rest to HTTPS, and each site sends an HSTS header.

Only the central `web` container publishes ports (80/443). No database or app
port is exposed to the host.

## Requirements

- Docker with the **Compose v2** plugin (`docker compose`).
- DNS `A` records for every domain above pointing at the VPS.
- Ports **80** and **443** open in the OVH firewall.
- A root `.env` file (see below), never committed.
- Access to the TeamBrewer images on GHCR (`ghcr.io/malexandre/teambrewer-{api,web}`).
  If those packages are **public**, nothing to do; if **private**, run
  `docker login ghcr.io` once (with a token that has `read:packages`) before deploying.

## Configuration (`.env`)

Create `.env` in the repo root and `chmod 600 .env`:

```dotenv
# --- TeamBrewer ---
# Postgres password for the TeamBrewer database.
TEAMBREWER_POSTGRES_PASSWORD=<strong-random-password>
# Better Auth signing secret — REQUIRED. Generate with: openssl rand -base64 32
TEAMBREWER_BETTER_AUTH_SECRET=<openssl rand -base64 32>

# Optional Discord SSO (leave unset/blank to disable):
# TEAMBREWER_DISCORD_CLIENT_ID=
# TEAMBREWER_DISCORD_CLIENT_SECRET=
# TEAMBREWER_DISCORD_REDIRECT_URI=https://brewer.malexandre.fr/api/auth/callback/discord

# Optional — pin the TeamBrewer image tag pulled from GHCR (default: 1.0.0).
# GHCR tags have no leading "v" (docker/metadata-action strips it):
# TEAMBREWER_VERSION=1.0.0
```

Do **not** reuse the dev `.env` from the TeamBrewer checkout — generate a fresh
`BETTER_AUTH_SECRET` for production.

## First deploy

```bash
EMAIL=you@example.com ./launch.sh
```

`launch.sh` creates the on-disk directories, downloads the single-file static pages
(`fetch-static-pages.sh`), issues Let's Encrypt certificates via
`init-letsencrypt.sh` (run once), **pulls the pre-built TeamBrewer images from
GHCR**, builds the local static-site images (blog, sfbdb), and starts everything.
Certificates renew automatically thereafter (the `certbot` service; `web` reloads
every 6h to pick them up). Deploying a new TeamBrewer release is just bumping
`TEAMBREWER_VERSION` in `.env` and running `./update.sh` (no build on the server).

### Finish setting up TeamBrewer (first run only)

The TeamBrewer API applies database migrations on boot, but reference data, card
data, and the first admin are **not** created automatically. Run once:

```bash
docker compose exec -e SEED_ADMIN_USERNAME=admin -e SEED_ADMIN_DISPLAY_NAME="Admin" \
  teambrewer-api sh -c "node dist/main.seed.js && node dist/main.cli.js && node dist/main.bootstrap.js"
```

- `main.seed.js` — seeds reference games + formats (required).
- `main.cli.js` — downloads the card database (needs outbound internet).
- `main.bootstrap.js` — creates the instance-admin and prints a one-time
  `SETUP_LINK=…`. Open it to set the admin password and enable TOTP 2FA.

## Redeploy

```bash
./update.sh
```

Pulls this repo, downloads the static pages again, pulls every pre-built image,
rebuilds the local static sites and restarts. Certificates and the TeamBrewer
database volume (`teambrewer-postgres-data`, a named volume) are left untouched,
so data persists across `docker compose down` — only `docker compose down -v`
would wipe it.

## Security updates

`./update.sh` is also how security releases reach the server: it pulls the Nginx,
Certbot and Postgres images again on every run. `docker compose up` alone keeps
the image already on the box, so run `./update.sh` after a security release.

- **Nginx** follows the stable branch (`nginx:1.30-alpine`), which only receives
  fixes. To move to the next stable branch, change the tag in
  `docker-compose.yaml`.
- **Postgres** stays on major version 17 (`postgres:17-alpine`): only minor
  releases arrive, and they keep the data volume valid.
- **TeamBrewer** ships its own Nginx inside the `teambrewer-web` image. It is
  updated by a new TeamBrewer release, then by bumping `TEAMBREWER_VERSION`.
- **The VPS itself** (system packages, Docker engine) is updated on the machine,
  outside this repo.

Check what the server runs with `docker compose exec web nginx -v`.

## Add a domain

1. Point the DNS `A` record of the domain at the VPS.
2. Add the domain to its certificate in `certificate-domains.sh`, and to the
   `server_name` of the `:80` block and a new `server` block in `nginx.conf`.
3. Deploy with `./update.sh`. The new site answers with the existing certificate,
   which does not cover its name yet.
4. Run `./expand-certificates.sh`. It issues the certificate again with the full
   list of domains and reloads Nginx.

## Backups (TeamBrewer database)

```bash
docker compose exec -T teambrewer-postgres \
  pg_dump -U teambrewer -d teambrewer -Fc > "teambrewer-$(date +%Y%m%d-%H%M%S).dump"
```
