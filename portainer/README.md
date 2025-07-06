# Portainer

## Overview

Portainer is a lightweight management UI that allows you to easily manage your Docker environments (Docker hosts or Swarm clusters). It provides a detailed overview of your Docker resources and enables you to build, manage, and maintain containers, images, volumes, networks, and more through a simple web interface.

## Requirements

- Docker (version recommended by your OS, typically a recent version). Portainer itself runs as a Docker container.
- Access to the Docker socket (`/var/run/docker.sock`) on the host where Portainer will run, to allow it to manage Docker.
- A web browser to access the Portainer interface.
- The `web` and `internal_network` Docker networks must be created (usually handled by a global `Makefile` or setup script).
- Traefik service running and configured for exposing web services (for default SSL setup).

## Dependencies

- **Traefik:** Used as a reverse proxy to expose Portainer securely with SSL. Portainer itself does not directly depend on Traefik to run, but the provided `docker-compose.yml` is configured to use it.
- **Docker Engine:** Portainer requires access to a running Docker engine's socket to manage Docker resources.

## Configuration

- Portainer configuration is primarily managed through its web interface after initial setup.
- There is no `.env.template` or specific `.env` file for this Portainer setup in the `portainer/` directory, as it doesn't require many environment variables for basic operation in this configuration.
- The root `.env` file (or global environment) should define `BASE_DOMAIN` for Traefik integration and `WEB_NETWORK_NAME`, `INTERNAL_NETWORK_NAME` for Docker networking.
- **Volume Mounts:**
    - `/var/run/docker.sock:/var/run/docker.sock`: This is crucial. It mounts the Docker socket from the host into the Portainer container, allowing Portainer to manage Docker.
    - `./data:/data`: This volume stores Portainer's persistent data, such as user configurations, endpoint information, and settings.
    - `/etc/localtime:/etc/localtime:ro`: Mounts the host's time configuration into the container for correct time display.
- **Traefik Labels:** The `docker-compose.yml` includes labels for Traefik to expose Portainer on `portainer.${BASE_DOMAIN}` via port `9000` internally.

## Usage

1.  Ensure Docker is running.
2.  Ensure the `BASE_DOMAIN` environment variable is set correctly in your global environment for Traefik.
3.  Start the Portainer service using the main project's Makefile or Docker Compose command:
    ```bash
    make up portainer
    # or from the root directory:
    # docker-compose -f portainer/docker-compose.yml up -d
    ```
4.  Access Portainer in your web browser at: `https://portainer.${BASE_DOMAIN}`.
5.  On the first visit, Portainer will prompt you to create an administrator account (username and password). Secure these credentials.
6.  After creating the admin account, you will be asked to connect to a Docker environment. Choose "Local" to manage the Docker environment where Portainer is running (via the mounted Docker socket).

## Troubleshooting

- **Cannot connect to Docker socket / "Unable to connect to Docker API":**
    - Verify that `/var/run/docker.sock` exists on the host and is correctly mounted into the Portainer container in `docker-compose.yml`.
    - Check permissions on `/var/run/docker.sock` on the host. The user running the Docker daemon (often root) owns this socket. Portainer's container typically runs as root and should have access.
- **Traefik Issues / Cannot access `https://portainer.${BASE_DOMAIN}`:**
    - Check Traefik logs.
    - Ensure `BASE_DOMAIN` is correctly set in your environment.
    - Verify DNS records for `portainer.${BASE_DOMAIN}` point to Traefik.
    - Confirm Portainer container is running: `docker ps -f name=portainer`.
- **Data Persistence Issues:**
    - Ensure the `./data` volume is correctly mapped and has appropriate write permissions for the user/group Docker is running containers as (often root internally for Portainer).

## Security Notes

- **Secure your Portainer admin account with a strong password.** This account has significant control over your Docker environment.
- Portainer is exposed via Traefik with automatic SSL in this setup.
- Access to the Docker socket (`/var/run/docker.sock`) grants broad control over the host's Docker environment. Ensure only trusted images/containers (like Portainer official) are given this access.
- Regularly update Portainer to the latest version for security patches and features.
- Consider using Portainer's built-in user management and role-based access control (RBAC) if multiple users need access.

## Additional Resources
- [Portainer Official Website](https://www.portainer.io/)
- [Portainer Documentation](https://docs.portainer.io/)
