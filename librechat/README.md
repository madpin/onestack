# LibreChat

## Overview

LibreChat is an open-source AI chat interface that supports multiple AI providers, offering a versatile platform for interacting with various language models. It features capabilities like multi-user support, message searching, and plugin integration. This instance is configured to utilize shared backend services for data persistence and search.

## Requirements

- Docker (version recommended by your OS, typically a recent version)
- A web browser to access the interface.
- The `web` and `internal_network` Docker networks must be created. (Usually handled by a global `Makefile` or setup script).
- Traefik service running and configured for exposing web services (for default SSL setup).
- Running instances of:
    - MongoDB (e.g., `shared/mongodb` service)
    - Meilisearch (e.g., `shared/meilisearch` service)
    - PostgreSQL (e.g., `shared/postgres` service, used by the RAG API)

## Dependencies

LibreChat consists of multiple internal services and relies on several external shared services:

- **Internal Services:**
    - `librechat-api`: The main backend API for LibreChat.
    - `rag_api`: Retrieval Augmented Generation API, likely for document-based Q&A or enhanced context.
- **External Shared Services:**
    - **Traefik:** Used as a reverse proxy to expose LibreChat securely with SSL.
    - **MongoDB (e.g., `shared/mongodb`):** Primary database for storing chat history, user data, etc. Accessed via `MONGO_URI`.
    - **Meilisearch (e.g., `shared/meilisearch`):** Search engine for message indexing and retrieval. Accessed via `MEILI_HOST` and `MEILI_MASTER_KEY`.
    - **PostgreSQL (e.g., `shared/postgres`):** Used by the `rag_api` for vector storage or other RAG-specific data. Accessed via `DB_HOST`, `DB_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`.

## Configuration

- Create a `.env` file in the `librechat` directory by copying from `librechat/.env.template`. This file will contain LibreChat-specific settings.
    ```bash
    cp librechat/.env.template librechat/.env
    ```
- Ensure the root `.env` file (or global environment) provides necessary variables for shared services like `MONGODB_ROOT_USER`, `MONGODB_ROOT_PASSWORD`, `MEILI_MASTER_KEY`, `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_PORT`, and `BASE_DOMAIN`.
- **Main Configuration File:** `librechat.yaml` (mounted to `/app/librechat.yaml` in the `api` container). This file controls:
    - AI provider endpoints and keys
    - Authentication settings (e.g., registration, social logins)
    - File upload limits and types
    - Search functionality enable/disable
    - Rate limiting
    - UI customizations
- **Environment Variables for `api` service:**
    - `HOST`: Host for the API to listen on (default: `0.0.0.0`).
    - `NODE_ENV`: Application environment (default: `production`).
    - `MONGO_URI`: Connection string for MongoDB.
    - `MEILI_HOST`: URL for Meilisearch.
    - `MEILI_MASTER_KEY`: Master key for Meilisearch.
    - `RAG_PORT`: Port for the RAG API (default: `8000`).
    - `RAG_API_URL`: Internal URL for the RAG API.
- **Environment Variables for `rag_api` service:**
    - `DB_HOST`, `DB_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`: PostgreSQL connection details.
    - `RAG_PORT`: Port for the RAG API to listen on.
- **Volume Mounts:**
    - `./librechat.yaml`:/app/librechat.yaml (Main config)
    - `./images`:/app/client/public/images (Custom images for UI)
    - `./uploads`:/app/uploads (User uploaded files)
    - `./logs`:/app/api/logs (Application logs)

## Usage

1.  Ensure Docker is running and all prerequisite services (MongoDB, Meilisearch, PostgreSQL, Traefik) are running.
2.  Set up the `librechat/.env` file and ensure global environment variables are correctly defined.
3.  Configure `librechat.yaml` according to your needs (e.g., add AI API keys).
4.  Start the LibreChat services using the main project's Makefile or Docker Compose:
    ```bash
    make up librechat
    # or from the root directory:
    # docker-compose -f librechat/docker-compose.yml up -d
    ```
5.  Access LibreChat in your web browser at: `https://librechat.${BASE_DOMAIN}`.

## Troubleshooting

- **Service Startup Issues:**
    - Check logs of individual containers (`librechat-api`, `rag_api`):
      ```bash
      docker logs librechat-api
      docker logs rag_api
      ```
    - Ensure dependent services (MongoDB, Meilisearch, PostgreSQL) are accessible from within the LibreChat containers. Test connectivity if unsure.
- **AI Model Connection Problems:**
    - Verify API keys and endpoints in `librechat.yaml`.
    - Check container logs for specific error messages from AI providers.
- **Search Not Working:**
    - Ensure Meilisearch is running and accessible.
    - Verify `MEILI_HOST` and `MEILI_MASTER_KEY` are correct.
    - Check `librechat.yaml` for search configuration.
- **RAG API Issues:**
    - Confirm PostgreSQL is running and accessible with the correct credentials.
    - Check `rag_api` logs for database connection errors or other issues.
- **Traefik Issues:** If not accessible via `https://librechat.${BASE_DOMAIN}`:
    - Check Traefik logs.
    - Ensure `BASE_DOMAIN` is correctly set.
    - Verify DNS records.

## Security Notes

- LibreChat is exposed via Traefik with automatic SSL.
- Securely manage all API keys for AI models and other services configured in `librechat.yaml` and environment variables.
- Review authentication settings in `librechat.yaml` to control user registration and access.
- Be mindful of file upload settings and potential security implications.
- Regularly update to the latest LibreChat version for security patches.
