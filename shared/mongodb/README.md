# Shared MongoDB Service

## Overview

This service provides a MongoDB database instance. It is configured to support multiple logical databases accessible by a single application user (`APP_USER`), in addition to the MongoDB root user. This setup is designed for use by various applications within the stack that require MongoDB for data storage.

## Requirements

- Docker (version recommended by your OS, typically a recent version, e.g., Mongo 8.0 compatible).
- The `internal_network` Docker network must be created.
- Root and application user credentials must be defined.

## Dependencies

This service typically has no external service dependencies to run itself, but other services depend on it.
- **Dependent Services (Examples):** Services like `LibreChat` and `MadPin` (hypothetical example based on init script) use this MongoDB instance.

## Configuration

- MongoDB credentials and settings are primarily defined in the root `.env` file. A `shared/mongodb/.env.template` is provided, and a `shared/mongodb/.env` can be used for service-specific overrides, though the `docker-compose.yml` currently comments out loading `shared/mongodb/.env`. It primarily loads `../../.env` (the root .env file).
- **Key Environment Variables (expected in root `.env`):**
    - `MONGODB_HOST`: Typically `mongodb` (the service name in Docker Compose).
    - `MONGODB_ROOT_USER`: Username for the MongoDB root administrator (e.g., `root`).
    - `MONGODB_ROOT_PASSWORD`: Password for the MongoDB root administrator. **Set a strong password.**
    - `MONGODB_USER`: Username for the application user (e.g., `appuser`).
    - `MONGODB_PASSWORD`: Password for the application user. **Set a strong password.**
    - `MONGODB_PORT`: Port on the host to expose MongoDB (e.g., `27017`). The container always runs MongoDB on port `27017`.
- The root `.env` file should also define `INTERNAL_NETWORK_NAME`.
- **Initialization Script:**
    - The script `mongo-init/01-create-single-user-multiple-databases.js` is executed when the MongoDB container starts for the first time (or when the data directory is empty).
    - This script:
        - Creates the application user (`APP_USER` with `APP_PASSWORD` from environment variables).
        - Grants this user `readWrite` access to specific databases (e.g., `librechat`, `madpin`, as defined by `LIBRECHAT_DB`, `MADPIN_DB` environment variables passed to the container).
        - Creates an initial collection in each database to ensure they are physically created.
- **To add new databases for the `APP_USER`:**
    1.  Modify `mongo-init/01-create-single-user-multiple-databases.js`:
        - Add new database names to the `databases` array.
        - If you need different users or more granular permissions, the script will need more significant changes.
    2.  If the container has already been initialized, you'll need to either:
        - Connect as the root user and create the new database and grant permissions manually.
        - Or, if acceptable, remove the existing data volume (`./data`) and let MongoDB re-initialize (this will delete all existing data).
- **Volume Mounts:**
    - `./data:/data/db`: Stores MongoDB data files.
    - `./config:/data/configdb`: Stores MongoDB configuration server data (relevant if using sharding, less critical for a single instance but good practice to map).
    - `./mongo-init:/docker-entrypoint-initdb.d:ro`: Mounts initialization scripts. Scripts in this directory are executed by the MongoDB entrypoint on first run.
- **Networking:**
    - Attached to `internal_network`. Accessible to other services at `mongodb:27017`.
    - Exposes `MONGODB_PORT` (e.g., 27017) on the host, allowing direct connections from the host machine if needed (e.g., for MongoDB Compass).

## Usage

1.  Ensure Docker is running.
2.  Define all required `MONGODB_*` variables (especially `MONGODB_ROOT_USER`, `MONGODB_ROOT_PASSWORD`, `MONGODB_USER`, `MONGODB_PASSWORD`) in your root `.env` file.
3.  Start the MongoDB service:
    ```bash
    # Usually started as a dependency or part of shared services.
    make up mongodb
    # Or directly:
    # docker-compose -f shared/mongodb/docker-compose.yml up -d
    ```
4.  Applications can connect using connection strings like:
    - For `librechat` database: `mongodb://${MONGODB_USER}:${MONGODB_PASSWORD}@mongodb:27017/librechat?authSource=admin`
    - For `madpin` database: `mongodb://${MONGODB_USER}:${MONGODB_PASSWORD}@mongodb:27017/madpin?authSource=admin`
    (Note: `authSource=admin` is typically used when the user is defined in the `admin` database, as is common for users intended to access multiple databases).

## Troubleshooting

- **Authentication Failures:**
    - Double-check usernames and passwords in your `.env` file and ensure they match what applications are using.
    - Verify the `authSource` parameter in the connection string is correct (usually `admin` if the user was created as per the init script).
    - Check MongoDB logs for authentication errors: `docker logs mongodb`.
- **Initialization Script Not Running / User Not Created:**
    - The init script only runs if the `/data/db` directory inside the container is empty. If MongoDB has started before with data, the script won't run again.
    - To force re-initialization (WARNING: DELETES ALL DATA): stop MongoDB, remove the host `./data` directory (`rm -rf shared/mongodb/data`), then restart MongoDB.
    - Check logs for errors during script execution.
- **Connectivity Issues:**
    - Ensure dependent services are on the same `internal_network`.
    - If connecting from the host, use `localhost:${MONGODB_PORT}` or `127.0.0.1:${MONGODB_PORT}`.

## Security Notes

- **Use strong, unique passwords** for `MONGODB_ROOT_PASSWORD` and `MONGODB_PASSWORD`.
- **Network Exposure:** The service exposes `MONGODB_PORT` to the host. If this is not needed, remove the `ports` mapping from `docker-compose.yml` to restrict access to only within the Docker internal network.
- **Data Backup:** Regularly back up the `./data` volume or use MongoDB's `mongodump` tool.
- The current image is `mongo:8.0`. Regularly check for and update to newer stable versions of MongoDB for security patches.

## Additional Resources
- [MongoDB Official Website](https://www.mongodb.com/)
- [MongoDB Docker Image Documentation](https://hub.docker.com/_/mongo)
- [MongoDB Connection String URI Format](https://www.mongodb.com/docs/manual/reference/connection-string/)
