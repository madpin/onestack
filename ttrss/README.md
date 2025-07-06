# Tiny Tiny RSS (TTRSS) with Mercury Parser

## Overview

Tiny Tiny RSS (TTRSS) is a free and open source web-based RSS feed aggregator. It allows you to subscribe to and read news feeds from various sources in one place. This setup includes the main TTRSS application and an optional Mercury Parser API service, which can be used by TTRSS (typically via a plugin) to fetch and declutter full article content from feed entries that only provide summaries.

## Requirements

- Docker (version recommended by your OS).
- The `web` and `internal_network` Docker networks must be created.
- Traefik service running and configured for exposing web services.
- A running PostgreSQL instance (e.g., `shared/postgres` service).
- User credentials for TTRSS and PostgreSQL must be defined.
- Host directory permissions for `./data` should allow the specified `UID:GID` to write to it.

## Dependencies

- **TTRSS Application (`ttrss` service):**
    - **Traefik:** Used as a reverse proxy to expose TTRSS securely with SSL.
    - **PostgreSQL (e.g., `shared/postgres`):** Primary database for storing feeds, articles, user data, etc. Accessed via `TTRSS_DB_*` variables. A dedicated database (e.g., `${POSTGRES_TTRSS_DB}`) is typically used.
    - **Mercury Parser API (`mercury-parser-api` service, optional):** Used to fetch full article content. TTRSS needs to be configured (usually via a plugin like `af_mercury_fulltext`) to use this service.
- **Mercury Parser API (`mercury-parser-api` service):**
    - No direct external dependencies for running, but TTRSS depends on it for full-text fetching.

## Configuration

- Create a `.env` file in the `ttrss` directory by copying from `ttrss/.env.template`, or ensure variables are set in the root `.env` file.
- **Key Environment Variables (expected in `ttrss/.env` or root `.env`):**
    - `BASE_DOMAIN`: Used for Traefik routing and constructing `TTRSS_SELF_URL_PATH`.
    - `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_TTRSS_DB` (TTRSS specific database name), `POSTGRES_HOST`, `POSTGRES_PORT`: For connecting to the PostgreSQL database.
    - `UID`, `GID`: User and group ID for file ownership within the TTRSS container (for `./data` volume).
    - `AUTO_CREATE_USER`: Username for an initial user to be automatically created by TTRSS.
    - `AUTO_CREATE_USER_PASS`: Password for the auto-created user. **Set a strong password.**
- **TTRSS Specific Environment Variables:**
    - `TTRSS_SELF_URL_PATH`: The full public URL of your TTRSS instance (e.g., `https://ttrss.${BASE_DOMAIN}`). This is crucial for TTRSS to function correctly.
    - `TTRSS_HTTP_HOST=0.0.0.0`: Makes TTRSS listen on all interfaces within the container.
    - `ADMIN_USER_ACCESS_LEVEL=-2`: Sets the access level for the admin user (value might vary based on image).
    - (Optional) `HTTP_PORT=8280`: If the TTRSS container listens on a port other than 80. The Traefik label `traefik.http.services.ttrss.loadbalancer.server.port` must match this. The current `docker-compose.yml` for TTRSS doesn't explicitly set `HTTP_PORT` and the Traefik service label is commented out, implying it might default to port 80 or another port expected by the `nventiveux/ttrss` image. **This needs verification.** If the image serves on port 80, the Traefik service port should be 80.
- The root `.env` file should also define `WEB_NETWORK_NAME` and `INTERNAL_NETWORK_NAME`.
- **Volume Mounts for `ttrss` service:**
    - `./config:/var/www/html/config.d`: For TTRSS custom configuration files (e.g., `config.php` overrides).
    - `./data:/var/www/html`: Persistent storage for TTRSS data, including feed favicons, cached files, etc. (Note: main article data is in PostgreSQL).
    - `./config/plugin.local:/srv/ttrss/plugins.local`: For installing custom or third-party TTRSS plugins.
- **Networking:**
    - `ttrss` service: Attached to `web` (for Traefik) and `internal_network`. Traefik exposes it at `ttrss.${BASE_DOMAIN}`.
    - `mercury-parser-api` service: Attached only to `internal_network`. It's accessed by TTRSS internally at `http://mercury-parser-api:3000` (default port for Mercury Parser API).

## Usage

1.  Ensure Docker is running and prerequisite services (PostgreSQL, Traefik) are operational.
2.  Define all required environment variables in your `.env` files.
3.  If using custom plugins, place them in `ttrss/config/plugin.local/`.
4.  If PostgreSQL requires a specific database for TTRSS (e.g., `${POSTGRES_TTRSS_DB}`), ensure it's created (often handled by an init script in the `shared/postgres` setup, or TTRSS might create it if the DB user has permission).
5.  Start the TTRSS services:
    ```bash
    make up ttrss
    # Or directly:
    # docker-compose -f ttrss/docker-compose.yml up -d
    ```
6.  Access TTRSS in your web browser at: `https://ttrss.${BASE_DOMAIN}`.
7.  Log in with the `AUTO_CREATE_USER` and `AUTO_CREATE_USER_PASS` credentials.
8.  Configure TTRSS settings, add feeds, and optionally configure plugins (like `af_mercury_fulltext` to use the `mercury-parser-api` service, pointing it to `http://mercury-parser-api:3000`).

## Troubleshooting

- **Login Issues / User Not Created:**
    - Verify `AUTO_CREATE_USER` and `AUTO_CREATE_USER_PASS` are set.
    - Check TTRSS container logs for errors during startup or user creation: `docker logs ttrss`.
    - Ensure the PostgreSQL database is accessible and TTRSS can write to it.
- **Feeds Not Updating:**
    - TTRSS relies on background tasks (often cron jobs or a daemonized update process) to fetch feeds. The `nventiveux/ttrss` image should handle this internally. Check its documentation if updates are problematic.
    - Verify network connectivity from the TTRSS container to the internet.
    - Check TTRSS logs for errors related to feed fetching.
- **Mercury Parser Integration Not Working:**
    - Ensure the `mercury-parser-api` container is running: `docker logs mercury-parser-api`.
    - If using a plugin like `af_mercury_fulltext` in TTRSS, ensure it's configured correctly to point to `http://mercury-parser-api:3000`.
- **Database Connection Errors:**
    - Confirm all `TTRSS_DB_*` environment variables are correct.
    - Ensure PostgreSQL is running and the specified database (`${POSTGRES_TTRSS_DB}`) exists and is accessible by `${POSTGRES_USER}`.
- **Traefik Issues / Incorrect URL or Styling:**
    - Critically, ensure `TTRSS_SELF_URL_PATH` is set correctly to the full public URL.
    - Check Traefik logs.
    - Verify `BASE_DOMAIN` is correct.
    - The Traefik service port for TTRSS (`traefik.http.services.ttrss.loadbalancer.server.port`) needs to match the port TTRSS listens on inside its container (e.g., 80 or 8280 if `HTTP_PORT` is set). This is currently commented out in the compose file, implying a default, which should be confirmed.

## Security Notes

- **Use strong, unique passwords** for `AUTO_CREATE_USER_PASS` and PostgreSQL.
- **`TTRSS_SELF_URL_PATH` must be accurate** to prevent potential security issues like session fixation if not set correctly for the public URL.
- HTTPS is handled by Traefik.
- Regularly update TTRSS and Mercury Parser images for security patches and features.
- Be cautious with plugins; only install them from trusted sources.

## Additional Resources
- [Tiny Tiny RSS Official Website](https://tt-rss.org/)
- [Awesome TTRSS (Plugins, Themes, etc.)](https://github.com/awesome-selfhosted/awesome-ttrss) (Useful for finding plugins like for Mercury)
- [Mercury Parser GitHub](https://github.com/postlight/mercury-parser) (for the underlying parser technology)
- Image used for TTRSS: `nventiveux/ttrss` (check Docker Hub for its specifics)
- Image used for Mercury: `wangqiru/mercury-parser-api` (check Docker Hub for its specifics)
