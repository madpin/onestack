# Shared PostgreSQL Service (with pgvector)

## Overview

This service provides a PostgreSQL database instance, utilizing the `pgvector/pgvector:pg17` image. This means it includes the `pgvector` extension, making it suitable for storing and searching vector embeddings, which is common in AI applications (e.g., for RAG with LLMs). It serves as a general-purpose SQL database for any application in the stack that requires PostgreSQL.

## Requirements

- Docker (version recommended by your OS, typically one compatible with PostgreSQL 17 and pgvector).
- The `internal_network` Docker network must be created.
- User credentials for PostgreSQL must be defined.
- Host directory permissions for `./data` should allow the specified `UID:GID` to write to it.

## Dependencies

This service typically has no external service dependencies to run itself, but other services depend on it.
- **Dependent Services (Examples):** Services like `n8n`, `LibreChat` (RAG API), `LiteLLM` (for logging/analytics), `OpenWebUI`, and `LobeChat` can use this PostgreSQL instance.

## Configuration

- PostgreSQL credentials and settings are primarily defined in the root `.env` file. A `shared/postgres/.env.template` is provided for reference of variables used by this service.
- **Key Environment Variables (expected in root `.env`):**
    - `POSTGRES_USER`: Username for the primary PostgreSQL user (e.g., `pguser`). This user will own databases created by default if no other owner is specified.
    - `POSTGRES_PASSWORD`: Password for the primary PostgreSQL user. **Set a strong password.**
    - `POSTGRES_PORT`: Port on the host to expose PostgreSQL (e.g., `5432`). The container always runs PostgreSQL on port `5432`.
    - `UID`: User ID on the host that should own the PostgreSQL data files.
    - `GID`: Group ID on the host that should own the PostgreSQL data files.
- The root `.env` file should also define `INTERNAL_NETWORK_NAME`.
- **Initialization Scripts (`./config/initdb`):**
    - SQL (`.sql`), SQL dump (`.sql.gz`), or shell (`.sh`) scripts placed in the `shared/postgres/config/initdb/` directory are executed by the PostgreSQL entrypoint when the container starts for the first time (or when the data directory is empty).
    - These scripts are used to:
        - Create databases (e.g., `CREATE DATABASE myapp_db;`).
        - Create specific users/roles and grant permissions.
        - Create schemas, tables, functions, enable extensions (like `CREATE EXTENSION IF NOT EXISTS vector;` which might be needed per-database).
        - Populate initial data.
    - Refer to the PostgreSQL Docker image documentation for more details on initialization script behavior.
    - **Note:** The `pgvector` extension is available in the image but often needs to be explicitly enabled per-database using `CREATE EXTENSION vector;` within an init script or by a superuser after setup.
- **Volume Mounts:**
    - `./data:/var/lib/postgresql/data`: Stores PostgreSQL data files. The `user: "${UID}:${GID}"` directive in `docker-compose.yml` means the PostgreSQL process inside the container will run as this UID/GID, and thus these IDs need write permission to the `./data` directory on the host.
    - `./config/initdb:/docker-entrypoint-initdb.d`: Mounts initialization scripts.
- **Networking:**
    - Attached to `internal_network`. Accessible to other services at `postgres:5432`.
    - Exposes `POSTGRES_PORT` (e.g., 5432) on the host, allowing direct connections from the host machine (e.g., for `psql` or GUI tools like pgAdmin).

## Usage

1.  Ensure Docker is running.
2.  Define `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_PORT`, `UID`, and `GID` in your root `.env` file. Ensure the directory `shared/postgres/data` on the host is writable by the specified `UID:GID`.
3.  Place any necessary initialization scripts (e.g., to create databases, users, enable extensions) in `shared/postgres/config/initdb/`. For example, to ensure `pgvector` is usable in a database named `app_db`, you might have an init script like:
    ```sql
    -- shared/postgres/config/initdb/01-init-db.sql
    CREATE DATABASE app_db;
    -- Connect to app_db and run the following, or run as superuser:
    -- CREATE EXTENSION IF NOT EXISTS vector;
    -- Note: You might need to grant specific user permissions to app_db as well.
    -- The POSTGRES_USER defined in .env will be a superuser by default.
    ```
    It's common practice for applications to create their own databases if they don't exist, or for init scripts to handle this. The `POSTGRES_USER` is a superuser and can create databases and extensions.
4.  Start the PostgreSQL service:
    ```bash
    make up shared-postgres
    # Or directly:
    # docker-compose -f shared/postgres/docker-compose.yml up -d
    ```
5.  Applications can connect using standard PostgreSQL connection strings, for example:
    `postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/your_database_name`

## Troubleshooting

- **Permission Denied for `./data` directory:**
    - Ensure the `UID` and `GID` specified in your `.env` file correspond to a user/group that has write access to the `shared/postgres/data` directory on your host machine. You might need to `chown -R UID:GID shared/postgres/data` on the host.
- **Authentication Failures (`password authentication failed for user "..."`):**
    - Double-check `POSTGRES_USER` and `POSTGRES_PASSWORD` in your `.env` file and ensure they match what applications or connection attempts are using.
    - Check PostgreSQL logs for details: `docker logs postgres`.
- **Initialization Scripts Not Running:**
    - Scripts in `/docker-entrypoint-initdb.d` only run if the `/var/lib/postgresql/data` directory inside the container is empty. If PostgreSQL has started before with data, scripts won't run again.
    - To force re-initialization (WARNING: DELETES ALL DATA): stop PostgreSQL, remove the host `./data` directory (`rm -rf shared/postgres/data`), then restart PostgreSQL.
- **`pgvector` Extension Not Found/Enabled:**
    - Although the image includes `pgvector`, it often needs to be enabled per-database. Connect to your target database as a superuser (like the default `POSTGRES_USER`) and run `CREATE EXTENSION IF NOT EXISTS vector;`. This can also be part of an init script, ensuring it targets the correct database.
- **Connectivity Issues:**
    - Ensure dependent services are on the same `internal_network`.
    - If connecting from the host, use `localhost:${POSTGRES_PORT}` or `127.0.0.1:${POSTGRES_PORT}`.

## Security Notes

- **Use strong, unique passwords** for `POSTGRES_PASSWORD`.
- **Network Exposure:** The service exposes `POSTGRES_PORT` to the host. If direct host access is not needed, remove the `ports` mapping from `docker-compose.yml` to restrict access to only within the Docker internal network.
- **Data Backup:** Regularly back up the `./data` volume or use PostgreSQL's `pg_dump` and `pg_restore` tools.
- **Principle of Least Privilege:** While the default `POSTGRES_USER` is a superuser, for applications, consider creating specific users with limited permissions to only the databases and tables they need access to. This can be done in init scripts.
- The current image is `pgvector/pgvector:pg17`. Regularly check for and update to newer stable versions for security patches and features.

## Additional Resources
- [PostgreSQL Official Website](https://www.postgresql.org/)
- [PostgreSQL Docker Image Documentation](https://hub.docker.com/_/postgres) (many environment variables and init behaviors are inherited)
- [pgvector GitHub Repository](https://github.com/pgvector/pgvector) (for usage of the vector extension)
