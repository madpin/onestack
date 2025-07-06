# Shared Redis Service

## Overview

This service provides a Redis in-memory data structure store. It can be used as a cache, message broker, or a general-purpose key-value store by other applications in the stack. This configuration includes password protection and persistence options (AOF and RDB snapshots).

## Requirements

- Docker (version recommended by your OS, typically compatible with `redis:alpine`).
- The `internal_network` Docker network must be created.
- A password for Redis must be defined.

## Dependencies

This service typically has no external service dependencies to run itself, but other services depend on it.
- **Dependent Services (Examples):** Services like `n8n` (for queuing), `LiteLLM` (for caching), and `OpenWebUI` (for WebSocket management) can use this Redis instance.

## Configuration

- The Redis password is primarily defined in the root `.env` file. A `shared/redis/.env.template` is provided for reference of variables used by this service.
- **Key Environment Variables (expected in root `.env`):**
    - `REDIS_PASSWORD`: Password required to connect to the Redis instance. **Set a strong password.**
    - `REDIS_PORT` (Optional, if different from default 6379 for host exposure, though not explicitly used by `docker-compose.yml` for host port variable): The port Redis listens on. The container always runs Redis on port `6379`. The `docker-compose.yml` maps host port `6379` to container port `6379`.
- The root `.env` file should also define `INTERNAL_NETWORK_NAME`.
- **Redis Configuration (via `command` in `docker-compose.yml`):**
    - `--requirepass ${REDIS_PASSWORD}`: Enables password authentication.
    - `--appendonly yes`: Enables Append Only File (AOF) persistence.
    - `--appendfsync everysec`: AOF fsync policy (fsync every second).
    - `--auto-aof-rewrite-percentage 100` / `--auto-aof-rewrite-min-size 64mb`: Configures automatic AOF rewriting.
    - `--save 900 1` / `--save 300 10` / `--save 60 10000`: Configures RDB snapshotting intervals (e.g., save if 1 change after 900s, 10 changes after 300s, etc.).
    - `--dir /data`: Specifies the directory for storing persistence files (AOF, RDB).
    - `--loglevel warning`: Sets the Redis log level.
- **Volume Mounts:**
    - `./data:/data`: Stores Redis persistence files (AOF and RDB).
- **Networking:**
    - Attached to `internal_network`. Accessible to other services at `redis:6379`.
    - Exposes port `6379` on the host, allowing direct connections from the host machine (e.g., for `redis-cli`).
- **Healthcheck:** A healthcheck is configured to ping Redis (with password) to ensure it's responsive.

## Usage

1.  Ensure Docker is running.
2.  Define `REDIS_PASSWORD` in your root `.env` file.
3.  Start the Redis service:
    ```bash
    make up shared-redis
    # Or directly:
    # docker-compose -f shared/redis/docker-compose.yml up -d
    ```
4.  Applications can connect to Redis using a Redis client library, targeting `redis:6379` and providing the `REDIS_PASSWORD`.
    - Connection URI might look like: `redis://default:${REDIS_PASSWORD}@redis:6379/0` (the `/0` specifies database 0, which is the default).

## Troubleshooting

- **Authentication Failures (`NOAUTH Authentication required.` or `WRONGPASS invalid username-password pair`):**
    - Double-check `REDIS_PASSWORD` in your `.env` file and ensure client applications are using it correctly.
    - When using `redis-cli` from the host or another container: `redis-cli -a YOUR_PASSWORD ping`.
- **Persistence Issues:**
    - Check Redis logs for errors related to AOF or RDB saving: `docker logs redis`.
    - Ensure the `./data` volume on the host has correct permissions for the user running the Redis process inside the container (typically the `redis` user defined in the official image).
- **Connectivity Issues:**
    - Ensure dependent services are on the same `internal_network`.
    - If connecting from the host, use `localhost:6379` or `127.0.0.1:6379`.
- **High Memory Usage:**
    - Redis is an in-memory store. Monitor its memory usage.
    - Configure eviction policies if memory limits are a concern (not explicitly set in this `docker-compose.yml` but can be added to the command).

## Security Notes

- **Use a strong, unique password** for `REDIS_PASSWORD`.
- **Network Exposure:** The service exposes port `6379` to the host. If direct host access is not needed, remove or comment out the `ports` mapping in `docker-compose.yml` to restrict access to only within the Docker internal network.
- **Data Backup:** While AOF and RDB provide persistence, regularly back up the `./data` volume for disaster recovery.
- The current image is `redis:alpine`. Regularly check for and update to newer stable versions for security patches.

## Additional Resources
- [Redis Official Website](https://redis.io/)
- [Redis Documentation](https://redis.io/docs/)
- [Redis Persistence](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/)
- [Redis Docker Image Documentation](https://hub.docker.com/_/redis)
