# OpenWebUI

## Overview

OpenWebUI is a user-friendly and versatile web interface for interacting with various Large Language Models (LLMs). It supports multiple LLM providers (like OpenAI, Anthropic, and models accessed via LiteLLM or Ollama), features a pipeline system for custom workflows, user management, RAG (Retrieval Augmented Generation) capabilities, and a clean chat interface. This deployment uses PostgreSQL for database persistence and can integrate with Redis for WebSocket management and SearXNG for web search.

Key features:
- Multi-model and multi-provider support (OpenAI, LiteLLM, Ollama, etc.)
- Extensible pipeline architecture (`openwebui-pipelines` service)
- User authentication and management
- RAG with local file uploads, web fetching, and search engine integration
- Customizable UI and default model settings
- WebSocket support for real-time communication

## Requirements

- Docker (version recommended by your OS, typically a recent version)
- The `web` and `internal_network` Docker networks must be created.
- Traefik service running and configured for exposing web services.
- Running instances of:
    - PostgreSQL (e.g., `shared/postgres` service) for database storage.
    - LiteLLM (e.g., `litellm` service) if using it as a proxy for LLMs.
    - Redis (e.g., `shared/redis` service) if `ENABLE_WEBSOCKET_SUPPORT=true` and `WEBSOCKET_MANAGER=redis`.
    - SearXNG (e.g., `shared/searxng` service) if `ENABLE_RAG_WEB_SEARCH=true` and `RAG_WEB_SEARCH_ENGINE=searxng`.
- Appropriate API keys for any commercial LLM services you intend to use (e.g., `OPENAI_API_KEY`).

## Dependencies

OpenWebUI in this configuration consists of a main service and a pipelines service, and can rely on several external shared services:

- **Internal Services:**
    - `openwebui`: The main web interface and backend.
    - `openwebui-pipelines`: Background processing service for custom OpenWebUI pipelines.
- **External Shared Services (depending on configuration):**
    - **Traefik:** Used as a reverse proxy to expose OpenWebUI securely with SSL.
    - **PostgreSQL (e.g., `shared/postgres`):** Primary database for users, chats, settings, etc. Accessed via `DATABASE_URL`. A dedicated database (e.g., `${OPENWEBUI_DB_NAME}`) is used.
    - **LiteLLM (e.g., `litellm` service):** Can act as a proxy to various LLMs. OpenWebUI connects to it via `OPENAI_API_BASE_URL` (often pointed to LiteLLM's OpenAI-compatible endpoint).
    - **Redis (e.g., `shared/redis`):** Used for managing WebSocket connections if enabled. Accessed via `WEBSOCKET_REDIS_URL`.
    - **SearXNG (e.g., `shared/searxng`):** Used for RAG web search capabilities. Accessed via `SEARXNG_QUERY_URL`.

## Configuration

- Create an `.env` file in the `openwebui` directory by copying from `openwebui/.env.template`.
    ```bash
    cp openwebui/.env.template openwebui/.env
    ```
- This local `openwebui/.env` file should define OpenWebUI specific settings and necessary API keys.
- Ensure the root `.env` file (or global environment) provides variables for shared services and OpenWebUI:
    - `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT`, `OPENWEBUI_DB_NAME`.
    - `REDIS_PASSWORD`, `REDIS_HOST`, `REDIS_PORT` (if using Redis for WebSockets).
    - `OPENAI_API_KEY` (can be your actual OpenAI key or a key for LiteLLM if LiteLLM is managing multiple underlying keys).
    - `WEBUI_SECRET_KEY`: A strong, random secret key for session management.
    - `BASE_DOMAIN` for Traefik integration.
    - Other variables as needed, e.g., `BRAVE_SEARCH_API_KEY`, `SERPER_API_KEY` if using those search engines.
- **Key Environment Variables for `openwebui` service (refer to `docker-compose.yml` for a full list):**
    - `WEBUI_SECRET_KEY`: **Critical for security.**
    - `DATABASE_URL`: PostgreSQL connection string.
    - `OPENAI_API_KEY`: Your primary LLM API key (could be OpenAI's or LiteLLM's master/virtual key).
    - `OPENAI_API_BASE_URL`: Endpoint for the LLM service (e.g., `http://litellm:4000/v1` to route through LiteLLM).
    - `ENABLE_SIGNUP`: `true` or `false` to allow new user registrations. The first user to register typically becomes an admin.
    - `DEFAULT_MODELS`: Comma-separated list of models to show by default (e.g., `ollama/llama3,openai/gpt-4o`). These often refer to models defined/proxied via LiteLLM or Ollama.
    - RAG settings (`RAG_*`), WebSocket settings (`ENABLE_WEBSOCKET_SUPPORT`, `WEBSOCKET_MANAGER`, `WEBSOCKET_REDIS_URL`), Search settings (`SEARXNG_QUERY_URL`, etc.).
- **Volume Mounts:**
    - `./data` (mounted to `/app/backend/data`): Stores OpenWebUI's persistent data, including SQLite DB (if not using PostgreSQL), uploaded files, RAG indexes, etc.
    - `./pipelines` (mounted to `/app/pipelines` for `openwebui-pipelines` service): Location for custom pipeline definition files.

## Usage

1.  Ensure Docker is running and all prerequisite services (PostgreSQL, Traefik, and optionally LiteLLM, Redis, SearXNG) are running and correctly configured.
2.  Set up the `openwebui/.env` file with your chosen settings, API keys, and a strong `WEBUI_SECRET_KEY`.
3.  Start the OpenWebUI services:
    ```bash
    make up openwebui
    # or from the root directory:
    # docker-compose -f openwebui/docker-compose.yml up -d
    ```
4.  Access OpenWebUI in your web browser at: `https://openwebui.${BASE_DOMAIN}`.
5.  If `ENABLE_SIGNUP=true`, the first user to register will typically gain admin privileges. Otherwise, admin users might need to be created via a different mechanism if signups are disabled.
6.  Configure LLM connections, models, and other settings within the OpenWebUI interface.

## Troubleshooting

- **Login/Signup Issues:**
    - Check `ENABLE_SIGNUP` and `WEBUI_AUTH` settings.
    - Verify `WEBUI_SECRET_KEY` is set.
    - Examine OpenWebUI container logs: `docker logs openwebui`.
- **Model Connection Problems:**
    - Ensure `OPENAI_API_BASE_URL` points to the correct LLM service (e.g., LiteLLM, Ollama, or OpenAI directly).
    - Verify `OPENAI_API_KEY` is correct and has access to the models you're trying to use.
    - If using LiteLLM, ensure LiteLLM is configured correctly with the upstream provider keys and models. Check LiteLLM logs.
- **Database Issues:**
    - Confirm `DATABASE_URL` is correct and PostgreSQL is accessible.
    - Check OpenWebUI logs for database-related errors.
- **RAG Functionality Not Working:**
    - Verify RAG settings (embedding engine, reranking model, API keys if needed).
    - If using web search, ensure `SEARXNG_QUERY_URL` (or other search engine URLs) are correct and the search service is operational.
- **Pipeline Issues:**
    - Check logs for the `openwebui-pipelines` service: `docker logs openwebui-pipelines`.
- **Traefik Issues:** If not accessible via `https://openwebui.${BASE_DOMAIN}`:
    - Check Traefik logs.
    - Ensure `BASE_DOMAIN` is correct.
    - Verify DNS records.

## Security Notes

- **`WEBUI_SECRET_KEY` is critical for session security.** Use a strong, unique, randomly generated key.
- Protect all API keys (`OPENAI_API_KEY`, etc.).
- Manage user registration (`ENABLE_SIGNUP`) and roles carefully.
- HTTPS is handled by Traefik.
- Regularly update OpenWebUI and its components (like `pipelines`) to the latest versions for security patches and features.

## Additional Resources
- [OpenWebUI GitHub](https://github.com/open-webui/open-webui)
- [OpenWebUI Documentation](https://docs.openwebui.com/)
- [OpenWebUI Pipelines GitHub](https://github.com/open-webui/pipelines)
