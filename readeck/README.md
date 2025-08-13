# Readeck (OneStack Service)

Self‑hosted bookmark & content extraction service powered by Readeck.
Upstream project: <https://readeck.org/>

## Deployment

This service is integrated into OneStack and routed through Traefik at:

    https://readeck.${BASE_DOMAIN}

Bring it up:

    make up readeck

Stop it:

    make down readeck

Tail logs:

    make logsf readeck

## Data Layout

The volume `./data` is mounted at `/readeck` inside the container and contains:

- `config.toml` (auto‑generated on first start if absent)
- `data/` (bookmark HTML, extracted content, media)
- `db.sqlite3` (SQLite default database)
- `content-scripts/` (if you add custom scripts)

Back it up regularly (see upstream docs for details).

## Configuration

Environment variables live in `.env` (copied from `.env.template`). Common overrides:

- `READECK_LOG_LEVEL` (error|warn|info|debug)
- `READECK_DATABASE_SOURCE` (set to a postgres:// URL to use shared Postgres)
- `READECK_MAIL_*` for SMTP (optional)
- `READECK_PUBLIC_SHARE_TTL` (hours for shared links)
- `READECK_SERVER_BASE_URL` (auto set in compose; override if needed)
- `READECK_SECRET_KEY` (normally auto‑generated; do not rotate after users exist)

After first start, you can also fine‑tune `config.toml` directly in `./data`.

## PostgreSQL (Optional)

SQLite is fine for most cases. For Postgres, ensure database & user exist (e.g. via `shared/postgres`). Then set in `.env`:

```bash
READECK_DATABASE_SOURCE=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/readeck
```

Restart the service.

## Custom Content Scripts

Uncomment the `content-scripts` volume line in `docker-compose.yml` and place scripts in `config/content-scripts/` (they appear under `/readeck/data/content-scripts`). Then set (if you need to override):

```bash
READECK_EXTRACTOR_CONTENT_SCRIPTS=["data/content-scripts"]
```

## Email

Populate `READECK_MAIL_HOST`, `READECK_MAIL_PORT`, credentials, and optional `READECK_MAIL_ENCRYPTION` (starttls|ssltls) to enable sharing links by email and password resets.

## Healthcheck

Container uses the built‑in `readeck healthcheck` command for basic liveness.

## Traefik

Labels expose the service internally at port 8000. No host port is published.

## Backups

Back up the entire `./data` directory. For point‑in‑time consistency with SQLite, stop the container briefly or copy the DB file atomically.

## Upgrading

Pull latest image and restart:

```bash
make pull readeck && make up readeck
```

(Or global `make pull` to refresh all.)

## License

Readeck license per upstream project; service integration scripts remain under this repository's license.
