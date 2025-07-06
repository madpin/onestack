# DBGate

## Overview

DBGate is a modern database administration tool. It provides a web-based interface for managing multiple database types including PostgreSQL, MySQL, SQL Server, MongoDB, Redis, and more. Its purpose is to offer a unified and accessible way to interact with various databases, simplifying tasks like querying, schema exploration, and data import/export.

## Requirements

- Docker (version recommended by your OS, typically a recent version)
- A web browser to access the interface.
- The `web` and `internal_network` Docker networks must be created. (Usually handled by a global `Makefile` or setup script).
- Traefik service running and configured for exposing web services (for default SSL setup).

## Dependencies

Based on the `docker-compose.yml` and typical usage:

- **Traefik:** Used as a reverse proxy to expose DBGate securely with SSL. DBGate itself does not directly depend on Traefik to run, but the provided `docker-compose.yml` is configured to use it.
- **PostgreSQL (Optional but common):** While DBGate can connect to many databases, the example configuration in `docker-compose.yml` and `.env.template` often includes a PostgreSQL connection (e.g., `mypg`). This would be an external PostgreSQL instance.
- **MongoDB (Optional but common):** Similar to PostgreSQL, the example configuration often includes a MongoDB connection (e.g., `mymongo`). This would be an external MongoDB instance.
- *Other Databases (as configured):* DBGate can connect to various other databases (MySQL, SQL Server, Redis, etc.) if they are running and accessible.

## Configuration

- Create a `.env` file in the root directory of the entire project, or ensure the necessary environment variables are available. DBGate inherits variables like `POSTGRES_HOST`, `POSTGRES_USER`, `MONGODB_HOST`, etc., from the global environment.
- The primary configuration for DBGate itself is done through environment variables defined in its `docker-compose.yml` section or inherited.
- To add or modify database connections:
    - Update the `CONNECTIONS` environment variable (e.g., `CONNECTIONS=mypg,myredis,mymongo`).
    - For each connection ID (e.g., `mypg`), define the following environment variables:
        - `LABEL_<id>`: A display name for the connection (e.g., `LABEL_mypg=Production PostgreSQL`)
        - `SERVER_<id>`: Hostname or IP of the database server (e.g., `SERVER_mypg=${POSTGRES_HOST}`)
        - `USER_<id>`: Username for the database (e.g., `USER_mypg=${POSTGRES_USER}`)
        - `PASSWORD_<id>`: Password for the database (e.g., `PASSWORD_mypg=${POSTGRES_PASSWORD}`)
        - `PORT_<id>`: Port number for the database (e.g., `PORT_mypg=${POSTGRES_PORT}`)
        - `ENGINE_<id>`: DBGate engine string (e.g., `ENGINE_mypg=postgres@dbgate-plugin-postgres`)
- Refer to the `dbgate/.env.template` for a list of environment variables used by this service.
- Data persistence:
    - Database schemas and saved queries are stored in the `./data` volume.
    - Configuration files are stored in the `./config` volume.

## Usage

1.  Ensure Docker is running and the required environment variables are set (see Configuration).
2.  Start the service using the main project's Makefile or Docker Compose command:
    ```bash
    make up dbgate
    # or from the root directory:
    # docker-compose -f dbgate/docker-compose.yml up -d
    ```
3.  Access DBGate in your web browser at: `https://dbgate.${BASE_DOMAIN}` (if using Traefik and the provided setup). If not using Traefik and you've exposed port 8080, it might be `http://localhost:8080`.

The configured database connections will be automatically available in the DBGate interface.

## Supported Database Engines

DBGate supports various database engines via plugins. Common examples include:

- PostgreSQL: `postgres@dbgate-plugin-postgres`
- MySQL: `mysql@dbgate-plugin-mysql`
- SQL Server: `mssql@dbgate-plugin-mssql`
- MongoDB: `mongo@dbgate-plugin-mongo`
- Redis: `redis@dbgate-plugin-redis`
- SQLite: `sqlite@dbgate-plugin-sqlite`

## Troubleshooting

- **Connection Issues:**
    - Verify database server address, port, username, and password.
    - Ensure the DBGate container can reach the database server (check Docker networking, firewalls).
    - Confirm the correct DBGate engine string is used for the database type.
- **Traefik Issues:** If not accessible via `https://dbgate.${BASE_DOMAIN}`:
    - Check Traefik logs.
    - Ensure `BASE_DOMAIN` is correctly set in your environment.
    - Verify DNS records for `dbgate.${BASE_DOMAIN}` point to Traefik.
- **Permissions:** Ensure the Docker user has permissions to write to the `./data` and `./config` volume mounts if issues arise with saving settings or data.

## Security Notes

- DBGate is exposed via Traefik with automatic SSL in the default setup.
- Database credentials are provided via environment variables. Ensure these are kept secure.
- Consider using strong, unique passwords for database access.
- Implement network isolation where appropriate (e.g., databases not exposed directly to the internet).
- Access to the DBGate interface itself should be controlled if deployed in a shared environment.
