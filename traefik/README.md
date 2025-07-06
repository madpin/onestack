# Traefik - Reverse Proxy and Load Balancer

## Overview

Traefik is a modern HTTP reverse proxy and load balancer that makes deploying microservices easy. It integrates with your existing Docker environment and configures itself automatically and dynamically. This service handles incoming HTTP/S traffic, routes requests to the appropriate backend services based on rules (e.g., hostname), and can automatically manage SSL/TLS certificates using Let's Encrypt.

## Requirements

- Docker (version recommended by your OS, typically compatible with `traefik:latest`).
- A publicly accessible server IP address.
- DNS records pointing your desired domain(s) (e.g., `*.${BASE_DOMAIN}`) to your server's public IP.
- Ports 80 (for HTTP and HTTP-01 ACME challenge) and 443 (for HTTPS) must be available on the host and open externally.
- The `web` Docker network must be created (this is the network Traefik will primarily manage for web-facing services).
- An email address for Let's Encrypt registration.
- Credentials for dashboard authentication.

## Dependencies

- **Docker Engine:** Traefik uses the Docker socket to discover services and their labels for dynamic configuration.
- **Let's Encrypt:** For automatic SSL certificate generation and renewal (requires internet connectivity and correct DNS setup).
- **Other Services:** While Traefik itself doesn't depend on other local services to run, all other web-exposed services in this stack depend on Traefik for public access and SSL.

## Configuration

- Traefik's configuration is primarily managed through command-line arguments in `docker-compose.yml` and environment variables defined in the root `.env` file. A `traefik/.env.template` is provided for reference.
- **Key Environment Variables (expected in root `.env`):**
    - `WEB_NETWORK_NAME`: Name of the Docker network Traefik will monitor for services (e.g., `web_default` or just `web`).
    - `ACME_EMAIL`: Your email address, used by Let's Encrypt for certificate registration and renewal notifications.
    - `BASE_DOMAIN`: The primary domain under which services will be hosted (e.g., `example.com`). Services will then be `servicename.example.com`.
    - `TRAEFIK_LOG_LEVEL`: Log level for Traefik (e.g., `DEBUG`, `INFO`, `WARN`, `ERROR`). Defaults to `DEBUG`.
    - `DASHBOARD_AUTH`: Credentials for accessing the Traefik dashboard, in the format `user:hashed_password`. You can generate the hashed password using `htpasswd` (e.g., `echo $(htpasswd -nb user password) | sed -e s/\\$/\\$\\$/g`).
- **Key Traefik Command Line Arguments (in `docker-compose.yml`):**
    - **Providers:**
        - `--providers.docker=true`: Enables Docker as a configuration provider.
        - `--providers.docker.exposedbydefault=false`: Services are only exposed if they have `traefik.enable=true` label.
        - `--providers.docker.watch=true`: Watches for Docker events to update configuration dynamically.
        - `--providers.docker.network=${WEB_NETWORK_NAME}`: Specifies the Docker network Traefik should monitor.
    - **Entrypoints:**
        - `--entrypoints.web.address=:80`: Defines an HTTP entrypoint on port 80.
        - `--entrypoints.web.http.redirections.entrypoint.to=websecure`: Redirects all traffic from `web` (HTTP) to `websecure` (HTTPS).
        - `--entrypoints.websecure.address=:443`: Defines an HTTPS entrypoint on port 443.
        - `--entrypoints.websecure.http.tls.certresolver=myresolver`: Specifies `myresolver` (Let's Encrypt) for TLS certificates on this entrypoint.
        - `--entrypoints.websecure.http3`: Enables HTTP/3 on the `websecure` entrypoint.
    - **Certificate Resolvers (Let's Encrypt):**
        - `--certificatesresolvers.myresolver.acme.email=${ACME_EMAIL}`
        - `--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json`: Path to store Let's Encrypt certificates.
        - `--certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web`: Uses HTTP-01 challenge on the `web` entrypoint.
        - (Optional) `--certificatesresolvers.myresolver.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory`: For testing Let's Encrypt configuration against their staging server to avoid rate limits. Comment out for production.
    - **Logging & API:**
        - `--log.level=${TRAEFIK_LOG_LEVEL:-DEBUG}`
        - `--api.dashboard=true`: Enables the Traefik dashboard.
    - **Misc:**
        - `--global.sendanonymoususage=false`: Disables sending anonymous usage statistics.
        - `--ping`: Enables the ping endpoint for health checks.
- **Volume Mounts:**
    - `./data:/letsencrypt`: Stores Let's Encrypt certificates and account information. This is critical to persist.
    - `/var/run/docker.sock:/var/run/docker.sock:ro`: Mounts the Docker socket (read-only) so Traefik can discover services.
- **Networking:**
    - Attached to the `web` network (defined by `WEB_NETWORK_NAME`).
    - Exposes ports `80` and `443` on the host.
- **Dashboard Configuration (via labels on Traefik service):**
    - The Traefik dashboard itself is exposed at `traefik.${BASE_DOMAIN}` and secured with basic authentication using `${DASHBOARD_AUTH}`.

## Usage

1.  Ensure Docker is running.
2.  Define `WEB_NETWORK_NAME`, `ACME_EMAIL`, `BASE_DOMAIN`, `TRAEFIK_LOG_LEVEL`, and `DASHBOARD_AUTH` in your root `.env` file.
3.  Ensure your DNS records for `*.${BASE_DOMAIN}` (or specific service subdomains like `traefik.${BASE_DOMAIN}`, `whoami.${BASE_DOMAIN}`, etc.) point to your server's public IP address.
4.  Ensure ports 80 and 443 are open on your server's firewall.
5.  Start the Traefik service:
    ```bash
    make up traefik
    # Or directly:
    # docker-compose -f traefik/docker-compose.yml up -d
    ```
6.  Traefik will start, connect to Docker, and begin listening for services that have Traefik labels.
7.  Access the Traefik dashboard at `https://traefik.${BASE_DOMAIN}` (login with `DASHBOARD_AUTH` credentials).
8.  Other services defined with appropriate Traefik labels (e.g., `traefik.enable=true`, `traefik.http.routers.myservice.rule=Host(\`myservice.${BASE_DOMAIN}\`)`, etc.) will be automatically discovered and exposed by Traefik with SSL.

## Troubleshooting

- **Certificates Not Issued / SSL Errors:**
    - Check Traefik logs for errors from Let's Encrypt (`myresolver`): `docker logs traefik`.
    - Ensure DNS records are fully propagated and correct.
    - Verify ports 80 and 443 are open and correctly forwarded to the Traefik container.
    - Make sure `ACME_EMAIL` is valid.
    - If you hit Let's Encrypt rate limits, use the staging server (`acme-staging-v02`) for testing.
- **Services Not Routed / 404 Errors:**
    - Check the Traefik dashboard to see if your services and routers are listed and healthy.
    - Verify the Traefik labels on your backend services are correct (hostname rules, service port, network).
    - Ensure backend services are on the network specified by `providers.docker.network` (`${WEB_NETWORK_NAME}`).
- **Dashboard Not Accessible or Auth Not Working:**
    - Confirm `DASHBOARD_AUTH` is correctly formatted (`user:hashed_password`) and the `BASE_DOMAIN` is correct.
    - Check Traefik logs.
- **HTTP to HTTPS Redirection Not Working:**
    - Ensure the redirection middleware is correctly configured on the HTTP entrypoint (`web`).

## Security Notes

- **Docker Socket Access:** Traefik requires access to the Docker socket. This is a privileged operation; ensure only the official Traefik image is used.
- **Dashboard Security:** The `${DASHBOARD_AUTH}` credentials protect your Traefik dashboard. Use a strong, unique password. Consider adding IP whitelisting or other security measures if exposing the dashboard to the internet.
- **Let's Encrypt Storage:** The `./data` volume (`/letsencrypt` in container) contains your SSL certificates and private keys. Protect this data.
- **Exposed by Default:** `providers.docker.exposedbydefault=false` is a good security practice, ensuring only explicitly labeled services are exposed.
- Regularly update Traefik to the latest version for security patches and features.

## Additional Resources
- [Traefik Official Website](https://traefik.io/)
- [Traefik Proxy Documentation](https://doc.traefik.io/traefik/)
- [Traefik Docker Provider Documentation](https://doc.traefik.io/traefik/providers/docker/)
- [Let's Encrypt](https://letsencrypt.org/)
