# Homepage

## Overview

Homepage is a modern, fully static, fast, secure, and highly customizable application dashboard. It serves as a start page or new tab page for your browser, providing quick access to your self-hosted applications and services. It supports integrations with various services to display information directly on the dashboard.

## Requirements

- Docker (version recommended by your OS, typically a recent version)
- A web browser to access the interface.
- The `web` and `internal_network` Docker networks must be created. (Usually handled by a global `Makefile` or setup script).
- Traefik service running and configured for exposing web services (for default SSL setup).
- The Docker socket (`/var/run/docker.sock`) needs to be accessible to the container if Docker integration features are used.

## Dependencies

- **Traefik:** Used as a reverse proxy to expose Homepage securely with SSL. Homepage itself does not directly depend on Traefik to run, but the provided `docker-compose.yml` is configured to use it.
- **Docker (runtime):** If using Docker integration features (e.g., to display container status), Homepage needs read-only access to the Docker socket (`/var/run/docker.sock`).

## Configuration

- Create a `.env` file in the root directory of the entire project, or ensure the necessary environment variables are available. Homepage uses variables like `BASE_DOMAIN`, `UID`, and `GID`.
- Refer to the `homepage/.env.template` for a list of environment variables used by this service.
- Key environment variables:
    - `HOMEPAGE_ALLOWED_HOSTS`: Sets the allowed host for accessing the homepage, typically `homepage.${BASE_DOMAIN}`.
    - `PUID` / `PGID`: User and group ID to run the Homepage process, for managing permissions on configuration files. These should match the owner of the `./config` and `./data` directories on the host.
- Configuration files for Homepage (bookmarks, services, widgets, settings) are located in the `./config` directory (mounted to `/app/config` in the container). These are YAML files:
    - `bookmarks.yaml`
    - `services.yaml`
    - `widgets.yaml`
    - `settings.yaml`
    - `docker.yaml` (for Docker integration)
    - `kubernetes.yaml` (for Kubernetes integration)
- Customize these YAML files to define the layout and content of your dashboard. Refer to the official Homepage documentation for details on configuration options.
- Data, such as custom icons or other assets, can be stored in the `./data` directory (mounted to `/app/data`).

## Usage

1.  Ensure Docker is running and the required environment variables are set (see Configuration).
2.  Ensure the `./config` directory is populated with your desired Homepage configuration files. You can start with the defaults provided by the Homepage project if available, or create your own.
3.  Start the service using the main project's Makefile or Docker Compose command:
    ```bash
    make up homepage
    # or from the root directory:
    # docker-compose -f homepage/docker-compose.yml up -d
    ```
4.  Access Homepage in your web browser at: `https://homepage.${BASE_DOMAIN}` (if using Traefik and the provided setup). If not using Traefik and you've exposed port 3000, it might be `http://localhost:3000`.

## Troubleshooting

- **Permission Issues:** If Homepage cannot read configuration files or write data, check that the `PUID`/`PGID` environment variables match the ownership of the `./config` and `./data` directories on the host machine.
- **Docker Socket Issues:** If Docker integration isn't working:
    - Verify that `/var/run/docker.sock` is correctly mounted into the container.
    - Ensure the user/group specified by `PUID`/`PGID` (or the default user the container runs as) has permission to access the Docker socket on the host. This often means the `PGID` should correspond to the `docker` group on the host.
- **Traefik Issues:** If not accessible via `https://homepage.${BASE_DOMAIN}`:
    - Check Traefik logs.
    - Ensure `BASE_DOMAIN` is correctly set in your environment.
    - Verify DNS records for `homepage.${BASE_DOMAIN}` point to Traefik.
- **Configuration Errors:** Homepage provides logs that can indicate errors in your YAML configuration files. Check container logs:
    ```bash
    docker logs homepage
    ```

## Security Notes

- Homepage is exposed via Traefik with automatic SSL in the default setup.
- If exposing Homepage publicly, ensure that any sensitive information or links are appropriate for public viewing or implement access controls if supported/needed.
- Be cautious with Docker socket access. While read-only is specified (`:ro`), misconfiguration could pose a security risk. Ensure the host system's Docker socket permissions are appropriate.
