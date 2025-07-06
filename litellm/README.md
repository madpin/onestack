# LiteLLM

## Overview

LiteLLM provides a unified interface to interact with a wide range of Large Language Models (LLMs) from various providers like OpenAI, Azure, Anthropic, Cohere, HuggingFace, Replicate, and more. It simplifies the process of calling different LLMs by offering a consistent API endpoint. This service can also handle API key management, request caching (with Redis), and logging/analytics (with PostgreSQL).

## Requirements

- Docker (version recommended by your OS, typically a recent version)
- The `web` and `internal_network` Docker networks must be created. (Usually handled by a global `Makefile` or setup script).
- Traefik service running and configured for exposing web services (for default SSL setup).
- Running instances of:
    - PostgreSQL (e.g., `shared/postgres` service) for logging and analytics.
    - Redis (e.g., `shared/redis` service) for caching.

## Dependencies

- **Traefik:** Used as a reverse proxy to expose LiteLLM securely with SSL.
- **PostgreSQL (e.g., `shared/postgres`):** Used for storing logs, analytics, and potentially other persistent data. Accessed via `DATABASE_URL`. A dedicated database (e.g., `litellm_db`) is typically used.
- **Redis (e.g., `shared/redis`):** Used for caching LLM responses to improve performance and reduce costs. Accessed via `REDIS_URL`.

## Configuration

- Create a `.env` file in the `litellm` directory by copying from `litellm/.env.template`. This file will contain LiteLLM-specific settings and credentials for shared services.
- Ensure the root `.env` file (or global environment) provides necessary variables like `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_LITELLM_DB` (for the LiteLLM specific database name), `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, `LITELLM_MASTER_KEY`, `LITELLM_SALT_KEY`, and `BASE_DOMAIN`.
- **Main Configuration File:** `config.yml` (mounted read-only to `/app/config.yaml` in the container). This YAML file is central to LiteLLM's operation and defines:
    - Model definitions: Mapping friendly names to specific provider models and their API keys.
    - Router settings: How requests are routed to different models.
    - API key management for virtual keys.
    - Logging, alerting, and UI settings.
    - Caching strategies.
- **Model Configuration Files:** YAML files within the `./models` directory (mounted read-only to `/app/models`). These files can further define specific model parameters or provider configurations, often imported into the main `config.yml`.
- **Key Environment Variables:**
    - `DATABASE_URL`: PostgreSQL connection string (e.g., `postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_LITELLM_DB}`).
    - `REDIS_URL`: Redis connection string (e.g., `redis://default:${REDIS_PASSWORD}@${REDIS_HOST}:${REDIS_PORT}/0`).
    - `LITELLM_MASTER_KEY`: A master key for LiteLLM, used for securing certain operations or creating virtual API keys.
    - `LITELLM_SALT_KEY`: A salt key used for cryptographic purposes within LiteLLM.
- The container command specifies `--config /app/config.yaml`, `--port 4000`, and `--detailed_debug`.

## Usage

1.  Ensure Docker is running and all prerequisite services (PostgreSQL, Redis, Traefik) are running.
2.  Set up the `litellm/.env` file and ensure global environment variables are correctly defined.
3.  Populate `litellm/config.yml` and any files in `litellm/models/` with your desired LLM provider details, API keys, and routing rules.
4.  Start the LiteLLM service using the main project's Makefile or Docker Compose:
    ```bash
    make up litellm
    # or from the root directory:
    # docker-compose -f litellm/docker-compose.yml up -d
    ```
5.  LiteLLM will be accessible via Traefik at `https://litellm.${BASE_DOMAIN}`.
6.  To make calls to LLMs, you would typically send requests to `https://litellm.${BASE_DOMAIN}/chat/completions` (or other relevant LiteLLM API endpoints), using a virtual API key defined in your `config.yml` or the `LITELLM_MASTER_KEY`.

## Troubleshooting

- **API Key Issues:**
    - Double-check that API keys for your LLM providers are correctly entered in `config.yml` or the respective files in the `models/` directory.
    - Ensure the `LITELLM_MASTER_KEY` is set if you are using features that require it.
- **Database/Redis Connection Errors:**
    - Verify `DATABASE_URL` and `REDIS_URL` are correct in the `litellm/.env` file.
    - Ensure PostgreSQL and Redis services are running and accessible from the LiteLLM container. Check network connectivity and credentials.
    - Check LiteLLM container logs for specific connection error messages: `docker logs litellm`.
- **Configuration Errors in `config.yml`:**
    - LiteLLM can be sensitive to YAML syntax. Validate your `config.yml`.
    - The `--detailed_debug` flag in the startup command should provide more verbose logging.
- **Traefik Issues:** If not accessible via `https://litellm.${BASE_DOMAIN}`:
    - Check Traefik logs.
    - Ensure `BASE_DOMAIN` is correctly set.
    - Verify DNS records.
- **Model Not Found / Routing Issues:**
    - Review your `config.yml` to ensure the model you're trying to call is correctly defined and routed.

## Security Notes

- LiteLLM is exposed via Traefik with automatic SSL.
- **Crucially, protect your `LITELLM_MASTER_KEY` and any LLM provider API keys stored in `config.yml` or `models/` files.** These grant access to potentially costly AI services.
- Use virtual API keys within LiteLLM for different applications/users to manage access and track usage.
- Regularly review and update LiteLLM to the latest version for security patches and new features.
- Be aware of the data sent to LLM providers, especially if it's sensitive. Understand the data privacy policies of the providers you use.
