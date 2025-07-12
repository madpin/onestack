# Copilot AI Agent Instructions for OneStack

## Project Overview
- **OneStack** is a modular, Docker-based self-hosting platform for running a curated set of services (apps, databases, proxies, AI tools) on a single server, managed via Makefile and Bash scripts.
- The architecture is directory-driven: each service (e.g., `homepage/`, `ttrss/`, `karakeep/`, `shared/postgres/`) has its own `docker-compose.yml`, config, and data folders.
- Central orchestration is via the root `Makefile` and `bash/onestack.sh` script, which wrap all Docker Compose operations and service lifecycle management.
- Traefik is used as a reverse proxy for SSL, routing, and service discovery. All public endpoints are exposed via Traefik labels in each service's compose file.
- Environment variables are managed globally in `.env` and per-service in `<service>/.env` files. These are critical for network, credentials, and domain configuration.

## Key Workflows
- **Start/Stop/Status:** Use `make up [service]`, `make down [service]`, `make status` (see Makefile for more).
- **Logs:** Use `make logs [service] [ARGS...]` or `make logsf <service>` for following logs.
- **Create New Service:** Use `make create-tool NAME=...` or `make create-shared NAME=...` to scaffold new app or infra service directories.
- **Network Management:** `make network` creates all required Docker networks as defined in `.env`.
- **Shell Access:** `make shell SERVICE=<name>` or `make shell-<service>` opens a shell in a running container.

## Project Conventions & Patterns
- **Service Structure:** Each service lives in its own directory with at least `docker-compose.yml`, `config/`, and `data/`.
- **Traefik Integration:** All public services must define Traefik labels for routing and SSL. See `README.md` for label examples.
- **Shared Services:** Infrastructure (databases, cache, search, etc.) are under `shared/` and are referenced by other services via Docker networks.
- **Plugin Development:** For app plugins (e.g., `ttrss/config/plugins.local/ttrss-plugin-tldr/`), follow the Tiny Tiny RSS plugin structure: main entry is `init.php`, with supporting JS and config files. See the plugin's `README.md` for details.
- **AI/LLM Integration:** AI features (e.g., TL;DR summaries, auto-tagging) are implemented as plugins (see `ttrss-plugin-tldr`). They use OpenAI-compatible APIs, with keys and endpoints set in plugin settings or `.env`.
- **Environment Management:** Always keep `.env` and `<service>/.env` in sync with actual deployment. Never hardcode secrets.

## Integration Points
- **Reverse Proxy:** All HTTP(S) traffic flows through Traefik. Service exposure is controlled by Traefik labels and network membership.
- **Databases:** Most apps use shared Postgres, MongoDB, or Redis. Connection details are injected via environment variables.
- **AI/LLM Services:** Some services (e.g., LiteLLM, LibreChat) provide AI APIs for other tools. These are referenced by internal DNS names (Docker service names).
- **Plugin Hooks:** For TT-RSS plugins, use the documented hooks (e.g., `HOOK_ARTICLE_FILTER`, `HOOK_ARTICLE_BUTTON`). See `init.php` in plugin directories for examples.

## Examples
- To add a new AI-powered plugin to TT-RSS, create a new directory under `ttrss/config/plugins.local/`, implement `init.php` with the required hooks, and register it in TT-RSS preferences.
- To expose a new service at `myapp.${BASE_DOMAIN}`, add the correct Traefik labels to its `docker-compose.yml` and ensure it joins the `web` network.
- To add a new shared database, use `make create-shared NAME=mydb`, then update dependent services' compose files and `.env`.

## Troubleshooting
- Check logs with `make logs [service]` or `docker compose logs` in the service directory.
- For plugin errors, enable debug mode in the app (e.g., TT-RSS) and check logs in `data/` or via the app UI.
- For network issues, verify Docker network membership and Traefik label correctness.

---

For more, see the root `README.md`, service-specific READMEs, and plugin documentation. When in doubt, follow the structure and patterns of existing services and plugins.