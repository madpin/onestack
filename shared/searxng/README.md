# Shared SearXNG Service

## Overview

SearXNG is a free and open-source internet metasearch engine which aggregates results from various search services without ads or tracking. This shared service provides a SearXNG instance that can be used directly by users as a privacy-respecting search engine, or integrated into other applications (e.g., LobeChat, OpenWebUI) to provide web search capabilities.

## Requirements

- Docker (version recommended by your OS, typically compatible with `searxng/searxng:latest`).
- The `web` and `tailscale_network` (or a similar internal network if Tailscale is not used for this) Docker networks must be created.
- Traefik service running and configured for exposing web services.
- A secret key for SearXNG must be defined.

## Dependencies

- **Traefik:** Used as a reverse proxy to expose SearXNG securely with SSL.
- **Dependent Services (Examples):** Services like `LobeChat` or `OpenWebUI` can use this SearXNG instance to provide web search functionality to their LLMs.

## Configuration

- SearXNG settings are primarily managed via its configuration files and environment variables.
- Create a `.env` file in the `shared/searxng/` directory by copying from `shared/searxng/.env.template`, or ensure variables are set in the root `.env` file.
- **Key Environment Variables (expected in root `.env` or `shared/searxng/.env`):**
    - `BASE_URL`: The public URL where SearXNG will be accessible (e.g., `https://searxng.${BASE_DOMAIN}/`). This is important for SearXNG to generate correct URLs.
    - `SEARXNG_SECRET_KEY`: A long, random string used by SearXNG for securing cookies and other internal purposes. **Generate a strong one.**
    - `BASE_DOMAIN`: Used to construct the `BASE_URL` and for Traefik routing.
- The root `.env` file should also define `WEB_NETWORK_NAME` and `TAILSCALE_NETWORK_NAME` (or the relevant internal network name).
- **Configuration Files (`./config`):**
    - The `shared/searxng/config/` directory is mounted to `/etc/searxng/` inside the container.
    - This directory should contain SearXNG's main configuration file, `settings.yml`. You can customize:
        - Enabled search engines and their settings.
        - Result formatting.
        - UI preferences.
        - Rate limits, proxies, and much more.
    - Refer to the official SearXNG documentation for details on `settings.yml`. A default or example `settings.yml` is usually provided by SearXNG or can be obtained from their repository.
- **Networking:**
    - Attached to `web` (for Traefik exposure) and `tailscale_network` (potentially for direct access via Tailscale, or could be `internal_network` if preferred for backend access).
    - Traefik exposes SearXNG at `searxng.${BASE_DOMAIN}` on port `8080` internally.
- **Healthcheck:** A healthcheck is configured to ensure SearXNG is responsive.

## Usage

1.  Ensure Docker is running.
2.  Define `BASE_URL` (or `BASE_DOMAIN` to construct it) and `SEARXNG_SECRET_KEY` in your relevant `.env` file.
3.  Configure `shared/searxng/config/settings.yml` to enable your desired search engines and customize other preferences. If a `settings.yml.new` is present, it might be a template to copy to `settings.yml`.
4.  Start the SearXNG service:
    ```bash
    make up shared-searxng
    # Or directly:
    # docker-compose -f shared/searxng/docker-compose.yml up -d
    ```
5.  Access SearXNG in your web browser at: `https://searxng.${BASE_DOMAIN}`.
6.  Other applications can use SearXNG by making HTTP GET requests to its search endpoint, typically: `https://searxng.${BASE_DOMAIN}/search?q=yourquery&format=json` (for JSON results) or other formats as configured. For internal access from other Docker containers, they might use `http://searxng:8080/search?q=yourquery...`.

## Troubleshooting

- **"Secret key not set" errors or cookie issues:**
    - Ensure `SEARXNG_SECRET_KEY` is set to a long, random string in your environment.
- **Search engines not working / No results:**
    - Check your `settings.yml` to ensure engines are correctly enabled and configured. Some engines might require API keys or specific settings.
    - View SearXNG logs for errors related to specific engines: `docker logs searxng`.
    - Some search engines may block requests from data centers or known Docker IP ranges. You might need to configure proxies for SearXNG.
- **Incorrect URLs or CSS issues:**
    - Verify the `BASE_URL` environment variable is correctly set to the public URL of your SearXNG instance, including the trailing slash.
- **Traefik Issues:** If not accessible via `https://searxng.${BASE_DOMAIN}`:
    - Check Traefik logs.
    - Ensure `BASE_DOMAIN` is correctly set.
    - Verify DNS records.

## Security Notes

- **`SEARXNG_SECRET_KEY` is important for security.** Use a strong, unique, randomly generated key.
- **Review enabled search engines:** Be aware of the terms of service and privacy policies of the search engines you enable through SearXNG.
- **Rate Limiting:** SearXNG can be configured with rate limits (globally or per-engine) to prevent abuse and avoid getting blocked by upstream search providers.
- HTTPS is handled by Traefik.
- Regularly update SearXNG to the latest version (`searxng/searxng:latest`) for security patches and features.

## Additional Resources
- [SearXNG Official Website](https://searxng.org/)
- [SearXNG Documentation](https://docs.searxng.org/)
- [SearXNG settings.yml Documentation](https://docs.searxng.org/admin/settings.html)
