# OneStack

**OneStack VPS** - A comprehensive Docker-based infrastructure stack for self-hosted services with automatic SSL certificates, reverse proxy, and centralized management.

## 🚀 Overview

OneStack is a production-ready Docker infrastructure that provides:

- **Automatic SSL certificates** via Let's Encrypt through Traefik
- **Reverse proxy** with automatic service discovery
- **Centralized environment management** with DRY principles
- **Network isolation** with internal and external networks
- **Automated service management** through Make targets
- **Template-based service creation** for rapid deployment

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Makefile Commands](#-makefile-commands)
- [Creating New Services](#-creating-new-services)
- [Available Tools](#-available-tools)
- [Shared Services](#-shared-services)
- [Traefik & Security](#-traefik--security)
- [Environment Configuration](#-environment-configuration)
- [Network Architecture](#-network-architecture)
- [Upcoming Services](#-upcoming-services)

## 🚀 Quick Start

1. **Clone and setup environment:**
   ```bash
   git clone <repository>
   cd onestack
   cp .env.template .env
   # Edit .env with your actual values
   ```

2. **Create networks and start services:**
   ```bash
   make network  # Create Docker networks
   make up       # Start all services
   ```

3. **Check status:**
   ```bash
   make status   # View all service statuses
   make logs     # View logs from all services
   ```

## 🛠️ Makefile Commands

The Makefile provides centralized management for the entire stack:

### Core Management
- `make help` - Show all available commands with examples
- `make network` - Create all required Docker networks
- `make up` - Start all discovered Docker services
- `make down` - Stop all running services
- `make restart` - Restart all services (down then up)
- `make clean` - Stop services and clean up networks/resources
- `make status` - Show status of all services

### Logging & Monitoring
- `make logs` - Show logs from all services
- `make logs ARGS='-f'` - Follow logs from all services
- `make logs-postgres` - Show logs for specific service
- `make logsf SERVICE=litellm` - Follow logs for specific service
- `make logs ARGS='-t 50 -f'` - Follow last 50 lines from all services

### Service Creation
- `make create-tool NAME=grafana` - Create a new tool
- `make create-shared NAME=elasticsearch` - Create a new shared service

### Environment Management
- `make reload` - Reload all .env files and export to current shell

## 🔧 Creating New Services

### Creating a New Tool

Tools are application services that provide specific functionality:

```bash
make create-tool NAME=grafana
```

This creates:
- `grafana/` directory with standard structure
- `grafana/docker-compose.yml` template
- `grafana/.env.template` and `grafana/.env` files
- `grafana/config/` and `grafana/data/` directories

### Creating a Shared Service

Shared services provide infrastructure components used by multiple tools:

```bash
make create-shared NAME=elasticsearch
```

This creates the same structure under `shared/elasticsearch/`

### Manual Service Configuration

After creation, you'll need to:

1. **Edit docker-compose.yml** to configure your service
2. **Update .env** with actual configuration values
3. **Add Traefik labels** for web exposure (if needed):
   ```yaml
   labels:
     - "traefik.enable=true"
     - "traefik.http.routers.myservice.rule=Host(`myservice.${BASE_DOMAIN}`)"
     - "traefik.http.routers.myservice.entrypoints=websecure"
     - "traefik.http.services.myservice.loadbalancer.server.port=8080"
   ```
4. **Configure networks**:
   ```yaml
   networks:
     - web                # For internet-facing services
     - internal_network   # For internal communication
   ```

## 🧰 Available Tools

### Production Tools

| Service | Purpose | URL Pattern | Dependencies |
|---------|---------|-------------|--------------|
| **Karakeep** | Knowledge management & bookmarking | `karakeep.${BASE_DOMAIN}` | PostgreSQL, Redis, Chrome, LiteLLM |
| **LiteLLM** | AI/LLM proxy & load balancer | `litellm.${BASE_DOMAIN}` | PostgreSQL, Redis |

### Dependencies Analysis

**Karakeep Dependencies:**
- PostgreSQL (database storage)
- Redis (caching & sessions)
- Chrome (web scraping & screenshots)
- LiteLLM (AI inference via OpenAI-compatible API)

**LiteLLM Dependencies:**
- PostgreSQL (configuration & usage tracking)
- Redis (caching & rate limiting)
- Multiple AI provider API keys (OpenAI, Anthropic, etc.)

## 🏗️ Shared Services

Shared services provide infrastructure components used across multiple tools:

### Database Services
- **PostgreSQL** (`postgres:5432`) - Primary relational database with pgvector extension
- **MongoDB** (`mongodb:27017`) - Document database with multi-database user setup
- **Redis** (`redis:6379`) - In-memory cache and session store

### Search & Processing
- **Meilisearch** (`meilisearch:7700`) - Fast, typo-tolerant search engine
- **Chrome** (`chrome:9222`) - Headless browser for web scraping and screenshots

### Service Details

| Service | Image | Port | Purpose | Health Check |
|---------|-------|------|---------|--------------|
| PostgreSQL | `pgvector/pgvector:pg17` | 5432 | Primary database with vector extensions | `pg_isready` |
| MongoDB | `mongo:8.0` | 27017 | Document database | `mongosh ping` |
| Redis | `redis:alpine` | 6379 | Cache & sessions | `redis-cli ping` |
| Meilisearch | `getmeili/meilisearch:v1.15` | 7700 | Search engine | Health endpoint |
| Chrome | `gcr.io/zenika-hub/alpine-chrome:123` | 9222 | Headless browser | Debug endpoint |

### Database Configuration

**PostgreSQL:**
- Includes pgvector extension for vector operations
- Automated schema initialization via `/docker-entrypoint-initdb.d`
- User/permission management via environment variables

**MongoDB:**
- Single user with access to multiple databases
- Pre-configured databases: `librechat`, `madpin`
- Automatic user creation with appropriate permissions

## 🔒 Traefik & Security

### How Traefik Works

Traefik acts as a reverse proxy and load balancer that:

1. **Automatically discovers services** via Docker labels
2. **Provides SSL termination** with Let's Encrypt certificates
3. **Routes traffic** based on hostname patterns
4. **Handles HTTP to HTTPS redirection**

### Service Exposure Configuration

To expose a service through Traefik, add these labels to your `docker-compose.yml`:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myservice.rule=Host(`myservice.${BASE_DOMAIN}`)"
  - "traefik.http.routers.myservice.entrypoints=websecure"
  - "traefik.http.services.myservice.loadbalancer.server.port=8080"
```

### Password Protection

To protect a service with HTTP Basic Auth:

1. **Generate password hash:**
   ```bash
   htpasswd -nb username "password"
   ```

2. **Add middleware labels:**
   ```yaml
   labels:
     - "traefik.http.routers.myservice.middlewares=myservice-auth"
     - "traefik.http.middlewares.myservice-auth.basicauth.users=user:$$2y$$10$$hash"
   ```

### Dashboard Protection

The Traefik dashboard is protected via:
- **Host rule:** Only accessible via `${BASE_DOMAIN}`
- **Basic auth:** Configured via `DASHBOARD_AUTH` in `traefik/.env`
- **Generate credentials:**
  ```bash
  htpasswd -nb admin "your-secure-password"
  ```

### SSL Certificates

- **Automatic issuance** via Let's Encrypt
- **HTTP Challenge** validation
- **Wildcard support** for subdomains
- **Certificate storage** in `traefik/data/acme.json`

## ⚙️ Environment Configuration

### Root Configuration (`.env`)

The main `.env` file contains global settings:

```bash
# Domain & SSL
BASE_DOMAIN=your-domain.com
ACME_EMAIL=your-email@example.com

# Networks
WEB_NETWORK_NAME=web
INTERNAL_NETWORK_NAME=onestack_internal_network

# User permissions
UID=1000
GID=1000

# Database credentials
POSTGRES_USER=your-postgres-username
POSTGRES_PASSWORD=your-postgres-password
MONGODB_ROOT_USER=root
MONGODB_ROOT_PASSWORD=your-mongodb-password
REDIS_PASSWORD=your-redis-password

# Service endpoints
MEILI_ADDR=http://meilisearch:7700
CHROME_ADDR=http://chrome:9222
```

### Service-Specific Configuration

Each service has its own `.env` file for service-specific settings:

- `traefik/.env` - Dashboard authentication
- `litellm/.env` - AI provider API keys and configuration
- `karakeep/.env` - Application-specific settings
- `shared/*/` - Infrastructure service settings

## 🌐 Network Architecture

### Network Topology

```
Internet
    ↓
[Traefik] (:80, :443)
    ↓
[web network] ← Internet-facing services
    ↓
[internal_network] ← Service-to-service communication
    ↓
[Individual Services]
```

### Network Types

1. **`web` Network:**
   - External network for internet-facing services
   - Traefik proxy network
   - Services exposed to the internet

2. **`internal_network` Network:**
   - Internal communication between services
   - Database connections
   - Service-to-service API calls

### Security Model

- **Default deny:** Services not explicitly exposed remain internal
- **Network isolation:** Internal services cannot be accessed directly
- **SSL termination:** All external traffic encrypted via Traefik
- **Access control:** Basic auth and custom middleware support

## 🔮 Upcoming Services

The following services are planned for future implementation:

### Communication & Collaboration
- **Open WebUI** - Modern AI chat interface
- **LobeChat** - Advanced AI conversation platform  
- **LibreChat** - Open-source ChatGPT alternative

### Content & Media
- **RSS Reader** - Feed aggregation and reading
- **Calibre-Web** - Ebook library management

### Development & Analytics
- **Langfuse** - LLM observability and analytics
- **ClickHouse** - Columnar database for analytics
- **SearXNG** - Privacy-focused search engine
- **CloudBeaver** - Database administration interface

### Implementation Timeline

These services will be added as:
1. **Tools** - Application services (OpenWebUI, LobeChat, LibreChat, RSS, Calibre-Web)
2. **Shared Services** - Infrastructure components (ClickHouse, SearXNG)
3. **Extensions** - Add-ons to existing services (Langfuse for LiteLLM, CloudBeaver for databases)

Each new service will follow the established patterns:
- Standardized directory structure
- Environment template files
- Traefik integration
- Health checks and monitoring
- Documentation and examples

---

## 📚 Additional Resources

- **Traefik Documentation:** [Official Traefik Docs](https://doc.traefik.io/traefik/)
- **Docker Compose Reference:** [Docker Compose Docs](https://docs.docker.com/compose/)
- **Let's Encrypt:** [SSL Certificate Documentation](https://letsencrypt.org/docs/)

## 🤝 Contributing

1. Follow the established directory structure
2. Include proper environment templates
3. Add Traefik labels for web services
4. Include health checks
5. Update this README with new services

---

**OneStack** - Simplifying self-hosted infrastructure management 🚀