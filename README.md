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

Only the central `web` container publishes ports (80/443). No database or app
port is exposed to the host.

## Requirements

- Docker with the **Compose v2** plugin (`docker compose`).
- DNS `A` records for every domain above pointing at the VPS.
- Ports **80** and **443** open in the OVH firewall.
- A root `.env` file (see below), never committed.

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
```

Do **not** reuse the dev `.env` from the TeamBrewer checkout — generate a fresh
`BETTER_AUTH_SECRET` for production.

## First deploy

```bash
EMAIL=you@example.com ./launch.sh
```

`launch.sh` creates the on-disk directories, fetches app sources (clones
TeamBrewer's `main`), issues Let's Encrypt certificates via `init-letsencrypt.sh`
(run once), then builds and starts everything. Certificates renew automatically
thereafter (the `certbot` service; `web` reloads every 6h to pick them up).

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

Pulls this repo, refreshes app sources (including TeamBrewer's latest `main`),
and rebuilds/restarts. Certificates and the TeamBrewer database volume
(`teambrewer-postgres-data`, a named volume) are left untouched, so data
persists across `docker compose down` — only `docker compose down -v` would wipe
it.

## Backups (TeamBrewer database)

```bash
docker compose exec -T teambrewer-postgres \
  pg_dump -U teambrewer -d teambrewer -Fc > "teambrewer-$(date +%Y%m%d-%H%M%S).dump"
```
