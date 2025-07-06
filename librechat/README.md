# LibreChat Service

LibreChat is an open-source AI chat interface that supports multiple AI providers. This service is configured to use the shared MongoDB, Meilisearch, and PostgreSQL services.

## Configuration

### Environment Variables

The service inherits configuration from the root `.env` file for database connections:

- `MONGODB_USER` - MongoDB username (from shared MongoDB service)
- `MONGODB_PASSWORD` - MongoDB password (from shared MongoDB service)
- `RAG_PORT` - RAG API port (default: 8000)

### Local Environment

Copy `.env.template` to `.env` and configure LibreChat-specific settings:

```bash
cp .env.template .env
```

### LibreChat Configuration

The `librechat.yaml` file contains LibreChat-specific configuration including:

- Database connection settings
- File upload limits
- Search configuration
- Rate limiting
- Authentication settings

## Services

### API Server
- **Container**: `librechat-api`
- **Port**: 3080
- **Image**: `ghcr.io/danny-avila/librechat-dev-api:latest`

### NGINX Proxy
- **Container**: `librechat-nginx`
- **Ports**: 80, 443
- **Image**: `nginx:1.27.0-alpine`

### RAG API
- **Container**: `rag_api`
- **Port**: 8000 (configurable)
- **Image**: `ghcr.io/danny-avila/librechat-rag-api-dev-lite:latest`

## Database Configuration

LibreChat uses the shared services:

- **MongoDB**: `mongodb://madpin:password@mongodb:27017/librechat?authSource=admin`
- **Meilisearch**: `http://meilisearch:7700`
- **PostgreSQL**: Used by RAG API for vector storage

## File Storage

The service mounts several directories:

- `./uploads` - User uploaded files
- `./logs` - Application logs
- `./images` - Static images
- `./librechat.yaml` - Configuration file

## Access

The service is accessible via Traefik at `https://librechat.${BASE_DOMAIN}`.

## Dependencies

Make sure the following shared services are running:
- MongoDB (`make up-shared-mongodb`)
- Meilisearch (`make up-shared-meilisearch`)
- PostgreSQL (`make up-shared-postgres`)

## Usage

```bash
# Start LibreChat
make up-librechat

# View logs
make logs-librechat

# Stop LibreChat
make down-librechat
```
