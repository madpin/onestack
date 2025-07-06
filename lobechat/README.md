# LobeChat

## Overview

LobeChat is a modern, open-source AI chat application. It provides a user-friendly interface for interacting with various Large Language Models (LLMs) and supports features like plugin integration, vision capabilities, and potentially web search integration via SearXNG. This deployment uses PostgreSQL for database persistence and can be configured with S3-compatible object storage for file handling and Auth0 for SSO.

## Requirements

- Docker (version recommended by your OS, typically a recent version)
- A web browser to access the interface.
- The `web` and `internal_network` Docker networks must be created.
- Traefik service running and configured for exposing web services.
- Running instances of:
    - PostgreSQL (e.g., `shared/postgres` service).
    - SearXNG (e.g., `shared/searxng` service) if web search integration is desired.
    - S3-compatible object storage (e.g., Cloudflare R2, MinIO) if using S3 features.
- Auth0 account and application configured if using Auth0 for SSO.

## Dependencies

- **Traefik:** Used as a reverse proxy to expose LobeChat securely with SSL.
- **PostgreSQL (e.g., `shared/postgres`):** Primary database for storing chat history, user data, and application state. Accessed via `DATABASE_URL`. A dedicated database (e.g., `${LOBE_DB_NAME}`) is used.
- **S3-compatible Object Storage (Optional):** For storing uploaded files, images, or other assets if configured. Accessed via `S3_*` environment variables.
- **SearXNG (Optional, e.g., `shared/searxng`):** For providing web search capabilities to the LLM. Accessed via `SEARXNG_URL`.
- **Auth0 (Optional):** For Single Sign-On (SSO) authentication. Configured via `NEXT_AUTH_SSO_PROVIDERS`, `AUTH_AUTH0_ID`, `AUTH_AUTH0_SECRET`, `AUTH_AUTH0_ISSUER`.

## Configuration

- Create a `.env` file in the `lobechat` directory by copying from `lobechat/.env.template`. This file will contain LobeChat-specific settings, credentials for shared services, Auth0 details, and S3 configuration.
- Ensure the root `.env` file (or global environment) provides necessary variables like `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT`, `LOBE_DB_NAME`, `S3_R2_PUBLIC_DOMAIN`, `S3_R2_ENDPOINT`, `S3_R2_ACCESS_KEY_ID`, `S3_R2_SECRET_ACCESS_KEY`, `S3_BUCKET`, `SEARXNG_ADDR`, `NEXT_AUTH_SECRET`, `AUTH0_CLIENT_ID`, `AUTH0_CLIENT_SECRET`, `AUTH0_DOMAIN_ADDR`, `KEY_VAULTS_SECRET`, and `BASE_DOMAIN`.
- **Key Environment Variables:**
    - **Authentication (Auth0 Example):**
        - `NEXT_AUTH_SSO_PROVIDERS=auth0`
        - `NEXT_AUTH_SECRET`: A secret key for NextAuth.
        - `AUTH_AUTH0_ID`: Client ID from your Auth0 application.
        - `AUTH_AUTH0_SECRET`: Client Secret from your Auth0 application.
        - `AUTH_AUTH0_ISSUER`: Your Auth0 domain (e.g., `https://your-tenant.auth0.com`).
        - `NEXTAUTH_URL`: The callback URL for NextAuth (e.g., `https://lobechat.${BASE_DOMAIN}/api/auth`).
    - **Database:**
        - `DATABASE_URL`: PostgreSQL connection string (e.g., `postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${LOBE_DB_NAME}`).
    - **S3/Object Storage (Example for Cloudflare R2):**
        - `S3_ENABLE_PATH_STYLE=1`
        - `S3_PUBLIC_DOMAIN`: Publicly accessible domain for your S3 bucket content.
        - `S3_ENDPOINT`: S3 API endpoint.
        - `S3_ACCESS_KEY_ID`: Access Key ID for S3.
        - `S3_SECRET_ACCESS_KEY`: Secret Access Key for S3.
        - `S3_BUCKET`: Name of the S3 bucket.
        - `S3_SET_ACL=0` (ACLs might not be needed/supported by all S3 providers like R2).
    - **Application Settings:**
        - `LLM_VISION_IMAGE_USE_BASE64=1`: How images are handled for vision models.
        - `SEARXNG_URL`: Address of the SearXNG instance (e.g., `http://searxng:8080`, derived from `${SEARXNG_ADDR}`).
        - `APP_URL`: Public base URL of the LobeChat application (e.g., `lobechat.${BASE_DOMAIN}`).
        - `KEY_VAULTS_SECRET`: Secret for encrypting sensitive keys or configurations.
    - LobeChat specific configurations (like LLM provider keys, default models, etc.) are typically managed within the LobeChat UI or via other environment variables as per LobeChat's documentation.

## Usage

1.  Ensure Docker is running and all prerequisite services (PostgreSQL, Traefik, and optionally S3, SearXNG, Auth0) are running and correctly configured.
2.  Set up the `lobechat/.env` file with all required credentials and configurations.
3.  Start the LobeChat service using the main project's Makefile or Docker Compose:
    ```bash
    make up lobechat
    # or from the root directory:
    # docker-compose -f lobechat/docker-compose.yml up -d
    ```
4.  Access LobeChat in your web browser at: `https://lobechat.${BASE_DOMAIN}`.
5.  If Auth0 is configured, you should be redirected to Auth0 for login.
6.  Configure LLM providers and other settings within the LobeChat application interface.

## Troubleshooting

- **Authentication Issues (Auth0):**
    - Verify all `AUTH_AUTH0_*` and `NEXTAUTH_URL` variables are correct in `.env` and match your Auth0 application settings (especially callback URLs).
    - Check LobeChat container logs for NextAuth errors: `docker logs lobechat`.
    - Ensure `NEXT_AUTH_SECRET` is set and is a strong, unique string.
- **Database Connection Errors:**
    - Verify `DATABASE_URL` is correct.
    - Ensure PostgreSQL is running, accessible, and the specified database (`${LOBE_DB_NAME}`) exists and the user has permissions.
- **S3 Connection/Upload Issues:**
    - Double-check all `S3_*` environment variables.
    - Ensure the S3 bucket exists and credentials have correct permissions.
    - Verify network connectivity to the S3 endpoint.
- **SearXNG Integration Problems:**
    - Ensure `SEARXNG_URL` is correct and the SearXNG service is running and accessible.
- **LLM Connection Issues:**
    - Typically configured within the LobeChat UI. Check API keys and endpoint settings there.
    - Review container logs for specific error messages.
- **Traefik Issues:** If not accessible via `https://lobechat.${BASE_DOMAIN}`:
    - Check Traefik logs.
    - Ensure `BASE_DOMAIN` is correctly set.
    - Verify DNS records.

## Security Notes

- LobeChat is exposed via Traefik with automatic SSL.
- **Protect your `NEXT_AUTH_SECRET`, `AUTH_AUTH0_SECRET`, S3 credentials, `KEY_VAULTS_SECRET`, and any LLM API keys configured within LobeChat.**
- Ensure your Auth0 application is configured securely (e.g., restrict callback URLs).
- If using S3, configure bucket policies appropriately to restrict access.
- Regularly update LobeChat to the latest version for security patches.
- Be aware of the data privacy implications of using third-party LLM providers.
