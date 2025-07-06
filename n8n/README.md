# n8n - Workflow Automation Tool

## Overview

n8n is a powerful, extendable workflow automation tool that allows you to connect various apps and services to create complex automated workflows without extensive coding. It uses a visual node-based editor. This deployment provides a production-ready setup with queue-based execution (Redis), database persistence (PostgreSQL), and a scalable worker architecture.

Key features include:
- Visual workflow builder
- 400+ integrations
- Queue-based execution for reliability and scalability
- Database persistence for workflows and execution data
- Webhook support
- Scalable main service + worker architecture
- Encrypted credential storage

## Requirements

- Docker (version recommended by your OS, typically a recent version)
- The `web` and `internal_network` Docker networks must be created.
- Traefik service running and configured for exposing web services.
- Running instances of:
    - PostgreSQL (e.g., `shared/postgres` service) for database storage.
    - Redis (e.g., `shared/redis` service) for queue management and caching.

You can typically start shared dependencies with a command like:
```bash
make up shared-postgres shared-redis # Adjust based on your Makefile
```

## Dependencies

n8n in this configuration consists of a main service and worker services, and relies on external shared services:

- **Internal Services:**
    - `n8n` (or `n8n-main`): The main n8n service handling the web interface, API, and workflow editing.
    - `n8n-worker`: Background worker processes (multiple replicas) that execute the workflows.
- **External Shared Services:**
    - **Traefik:** Used as a reverse proxy to expose n8n securely with SSL.
    - **PostgreSQL (e.g., `shared/postgres`):** Stores all workflow data, execution logs, and credentials. Accessed via `DB_POSTGRESDB_*` variables. A dedicated database (e.g., `${POSTGRES_N8N_DB}`) is used.
    - **Redis (e.g., `shared/redis`):** Manages the job queue for workflow executions, enabling asynchronous processing and scalability. Accessed via `QUEUE_BULL_REDIS_*` variables.

## Configuration

- Create an `.env` file in the `n8n` directory by copying from `n8n/.env.template`.
    ```bash
    cp n8n/.env.template n8n/.env
    ```
- This local `n8n/.env` file should define n8n specific settings:
    - `N8N_BASIC_AUTH_ACTIVE`: Set to `true` to enable basic authentication.
    - `N8N_BASIC_AUTH_USER`: Username for basic auth.
    - `N8N_BASIC_AUTH_PASSWORD`: Password for basic auth.
    - `N8N_ENCRYPTION_KEY`: **Crucial for security.** A randomly generated 32-character string used to encrypt credentials stored by n8n.
    - `N8N_TIMEZONE`: Timezone for n8n operations, e.g., `UTC` or `America/New_York`.
- Ensure the root `.env` file (or global environment) provides necessary variables for shared services:
    - `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_N8N_DB` (n8n specific database name), `POSTGRES_USER`, `POSTGRES_PASSWORD`.
    - `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`.
    - `BASE_DOMAIN` for Traefik integration.
- **Database Setup:** n8n will automatically create the necessary database tables in the specified `${POSTGRES_N8N_DB}` on its first run.
- **File Structure & Volumes:**
    - `./data` (mounted to `/home/node/.n8n`): Stores n8n's persistent data including workflows, credentials, and execution logs if not using a DB for everything. With DB persistence, this primarily holds config and user data.
    - `./config/local-files` (mounted to `/files`): Allows workflows to access local files from this directory.
- **Worker Scaling:** To adjust the number of worker processes, modify `deploy.replicas` in `n8n/docker-compose.yml` for the `n8n-worker` service.
- **Custom Nodes:** To add custom n8n nodes, you can mount them to `/home/node/.n8n/custom` in the `n8n` and `n8n-worker` service definitions.

## Usage

1.  Ensure Docker is running and all prerequisite services (PostgreSQL, Redis, Traefik) are running and correctly configured.
2.  Set up the `n8n/.env` file with your chosen authentication details and a strong `N8N_ENCRYPTION_KEY`.
3.  Start the n8n services:
    ```bash
    make up n8n
    # or from the root directory:
    # docker-compose -f n8n/docker-compose.yml up -d
    ```
4.  Access n8n in your web browser at: `https://n8n.${BASE_DOMAIN}`.
    - You will be prompted for the basic authentication credentials if `N8N_BASIC_AUTH_ACTIVE=true`.
5.  **View Logs:**
    ```bash
    make logs n8n          # All n8n services (main and workers)
    # or individually:
    docker logs n8n          # Main service
    docker logs $(docker ps -q --filter name=n8n-worker) # Worker services
    ```

## Troubleshooting

- **Database Connection Issues:**
    - Ensure PostgreSQL is running and accessible.
    - Verify all `DB_POSTGRESDB_*` variables are correct in `docker-compose.yml` (sourced from environment).
    - Check n8n container logs for specific database errors.
- **Redis Connection Issues:**
    - Ensure Redis is running and accessible.
    - Verify `QUEUE_BULL_REDIS_*` variables are correct.
    - Check n8n container logs for Redis errors.
- **Authentication Problems:**
    - Double-check `N8N_BASIC_AUTH_USER` and `N8N_BASIC_AUTH_PASSWORD` in `n8n/.env`.
    - Ensure `N8N_BASIC_AUTH_ACTIVE=true`.
- **Workflow Execution Issues:**
    - Check `n8n-worker` logs for execution errors.
    - Verify `EXECUTIONS_MODE=queue` is set.
    - Ensure Redis is functioning correctly as the queue manager.
- **`N8N_ENCRYPTION_KEY` not set or changed:** If this key is missing or changed after initial setup, n8n will not be able to decrypt previously saved credentials. Ensure it's set correctly and backed up.
- **SSL/Domain Issues with Traefik:**
    - Check Traefik logs.
    - Verify `BASE_DOMAIN` is correct.
    - Ensure DNS records for `n8n.${BASE_DOMAIN}` point to Traefik.

## Security Notes

- **`N8N_ENCRYPTION_KEY` is critical.** Use a strong, unique, randomly generated 32-character key. Back it up securely. If lost, encrypted credentials cannot be recovered.
- Use strong passwords for `N8N_BASIC_AUTH_PASSWORD`.
- HTTPS is handled by Traefik.
- Consider network policies if running in Kubernetes or similar environments to restrict access between containers.
- Regularly update n8n to the latest version for security patches and features.

## Additional Resources
- [n8n Official Documentation](https://docs.n8n.io/)
- [n8n Community Forum](https://community.n8n.io/)
- [n8n Workflow Templates](https://n8n.io/workflows/)
