# Shared Meilisearch Service

## Overview

Meilisearch is a fast, open-source, and easy-to-use search engine. This shared service provides a Meilisearch instance that can be used by other applications in the stack (e.g., LibreChat) for indexing data and providing powerful search capabilities.

## Requirements

- Docker (version recommended by your OS, typically a recent version).
- The `internal_network` Docker network must be created (usually handled by a global `Makefile` or setup script).
- A master key for Meilisearch must be defined.

## Dependencies

This service typically has no external service dependencies to run itself, but other services depend on it.
- **Dependent Services (Examples):** Services like `LibreChat` use Meilisearch for indexing messages and providing search functionality.

## Configuration

- Create a `.env` file in the `shared/meilisearch/` directory by copying from `shared/meilisearch/.env.template` if specific overrides are needed, or ensure variables are set in the root `.env` file.
- The `docker-compose.yml` is configured to load environment variables from `../../.env` (the root .env file) and then `shared/meilisearch/.env` (for potential service-specific overrides).
- **Key Environment Variables:**
    - `MEILI_MASTER_KEY`: **This is a critical security variable.** It's the master key required to protect access to Meilisearch's administrative routes (like creating indexes or changing settings) and to derive API keys. This should be a strong, randomly generated string. It's typically set in the root `.env` file.
    - `MEILI_NO_ANALYTICS`: Set to `true` to disable sending anonymous telemetry data to Meilisearch.
    - `MEILI_ENV`: Set to `production` for production environments. This can influence logging and other behaviors.
- The root `.env` file (or global environment) should also define `INTERNAL_NETWORK_NAME`.
- **Volume Mounts:**
    - `./data:/meili_data`: This volume stores Meilisearch's persistent data, including all indexes, documents, and configuration.
- **Networking:**
    - The service is attached to the `internal_network`, making it accessible to other services on the same network at `http://meilisearch:7700`.
    - It does **not** expose any ports to the host or through Traefik by default, as it's intended for internal use by other services.
- **Healthcheck:** A healthcheck is configured to ensure the Meilisearch instance is available and responding correctly.

## Usage

1.  Ensure Docker is running.
2.  Ensure the `INTERNAL_NETWORK_NAME` and `MEILI_MASTER_KEY` environment variables are correctly set in your root `.env` file.
3.  Start the Meilisearch service. This is typically done as a dependency of another service or as part of a general "up" command for shared services.
    ```bash
    # Usually started as a dependency. To start it directly (e.g., for testing):
    # docker-compose -f shared/meilisearch/docker-compose.yml up -d
    # Or if part of a larger shared services Makefile target:
    make up meilisearch
    ```
4.  Other services can then connect to this Meilisearch instance using a Meilisearch client library, targeting `http://meilisearch:7700` and using an appropriate API key (which can be generated using the `MEILI_MASTER_KEY` or the master key itself for admin operations).

## Troubleshooting

- **Service not starting/crashing:**
    - Check container logs: `docker logs meilisearch` (or the actual container name if different).
    - Ensure `MEILI_MASTER_KEY` is set. Meilisearch will not start in production mode without it.
    - Verify permissions on the `./data` volume mount if there are issues with data persistence.
- **Other services cannot connect:**
    - Verify the dependent service is on the same `internal_network` as the `meilisearch` service.
    - Ensure the dependent service is using the correct address (`http://meilisearch:7700`) and a valid API key.
    - Check Meilisearch logs for any connection attempt errors.
- **Search issues / Indexing problems:**
    - Consult the Meilisearch documentation for indexing best practices and query syntax.
    - Use tools like `curl` or a Meilisearch client to directly interact with the Meilisearch API for debugging (e.g., checking index settings, searching directly). Remember to include the API key in your requests.
    ```bash
    # Example: Get instance health (no key needed for this specific public endpoint)
    # docker exec meilisearch curl http://localhost:7700/health
    # Example: List indexes (requires an API key with search permissions)
    # docker exec meilisearch curl -H "Authorization: Bearer YOUR_API_KEY" http://localhost:7700/indexes
    ```

## Security Notes

- **`MEILI_MASTER_KEY` is extremely important.** Secure it properly. Anyone with this key has full administrative access to your Meilisearch instance.
- **API Keys:** Use restricted API keys for client applications rather than the master key. Generate API keys with specific permissions (e.g., search-only, specific index access) and expiration dates.
- **Network Exposure:** This service is intentionally not exposed publicly via Traefik or host ports. It should only be accessible on the internal Docker network by other trusted services.
- **Data Backup:** Regularly back up the `./data` volume or use Meilisearch's dump feature to create snapshots of your indexes, especially in production.
- Regularly update Meilisearch to the latest version for security patches and features. The current image is `getmeili/meilisearch:v1.15`. Check for newer stable versions.

## Additional Resources
- [Meilisearch Official Website](https://www.meilisearch.com/)
- [Meilisearch Documentation](https://docs.meilisearch.com/)
- [Meilisearch API Key Management](https://docs.meilisearch.com/learn/security/api_keys.html)
