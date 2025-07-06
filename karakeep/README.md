# KaraKeep

## Overview

KaraKeep is an application designed to help you keep and organize information, possibly with a focus on web content capture or personal knowledge management. (The exact functionality should be verified from the KaraKeep application's official documentation if more detail is needed, as it's not fully evident from the compose file alone). It uses a browser engine (like Chrome) for some of its operations.

## Requirements

- Docker (version recommended by your OS, typically a recent version)
- A web browser to access the interface.
- The `web` and `internal_network` Docker networks must be created. (Usually handled by a global `Makefile` or setup script).
- Traefik service running and configured for exposing web services (for default SSL setup).
- A running instance of a headless Chrome browser, accessible at the address specified by `BROWSER_WEB_URL` (e.g., `shared/chrome` service).

## Dependencies

- **Traefik:** Used as a reverse proxy to expose KaraKeep securely with SSL.
- **Headless Chrome (e.g., `shared/chrome` service):** KaraKeep requires a browser engine for its operations, as indicated by the `BROWSER_WEB_URL` environment variable. This is specified by `${CHROME_ADDR}` which typically points to a service like the `shared/chrome` container.

## Configuration

- Create a `.env` file in the `karakeep` directory, or ensure the necessary environment variables are set globally. KaraKeep specifically uses an `.env` file located at `karakeep/.env`.
- Refer to the `karakeep/.env.template` for a list of environment variables used by this service.
- Key environment variables:
    - `KARAKEEP_VERSION`: Specifies the version of KaraKeep to use (defaults to `release`).
    - `NEXTAUTH_URL`: The public URL for KaraKeep, used for authentication callbacks (e.g., `https://karakeep.${BASE_DOMAIN}`).
    - `BROWSER_WEB_URL`: The address of the headless Chrome service (e.g., `ws://chrome:3000`, derived from `${CHROME_ADDR}`).
    - Other variables related to NextAuth or KaraKeep's specific functionalities might be required in its `.env` file. Consult KaraKeep's documentation for a full list.
- Data is stored in the `./data` volume (mounted to `/data` in the container).
- Configuration files might be stored in the `./config` volume (mounted to `/config` in the container).

## Usage

1.  Ensure Docker is running and the required environment variables are set (see Configuration), particularly in `karakeep/.env`.
2.  Ensure the dependency services (Traefik, Headless Chrome) are running.
3.  Start the service using the main project's Makefile or Docker Compose command:
    ```bash
    make up karakeep
    # or from the root directory:
    # docker-compose -f karakeep/docker-compose.yml up -d
    ```
4.  Access KaraKeep in your web browser at: `https://karakeep.${BASE_DOMAIN}` (if using Traefik and the provided setup).

## Troubleshooting

- **Authentication Issues (NextAuth):**
    - Verify `NEXTAUTH_URL` is correctly set and reachable.
    - Check KaraKeep container logs for NextAuth-related errors.
- **Browser/Chrome Connectivity:**
    - Ensure the `BROWSER_WEB_URL` (derived from `${CHROME_ADDR}`) is correct and the headless Chrome service is running and accessible from the KaraKeep container.
    - Check network connectivity between KaraKeep and the Chrome service on the `internal_network`.
- **Traefik Issues:** If not accessible via `https://karakeep.${BASE_DOMAIN}`:
    - Check Traefik logs.
    - Ensure `BASE_DOMAIN` is correctly set in your environment.
    - Verify DNS records for `karakeep.${BASE_DOMAIN}` point to Traefik.
- **Configuration Errors:** Check KaraKeep container logs for any specific error messages:
    ```bash
    docker logs karakeep
    ```

## Security Notes

- KaraKeep is exposed via Traefik with automatic SSL in the default setup.
- Pay attention to the security implications of `NEXTAUTH_URL` and ensure it's configured correctly.
- Ensure the headless Chrome service is secured and not unnecessarily exposed.
