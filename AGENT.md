# AGENT.md - OneStack Docker Management System

## Build/Test Commands
- `make up [service]` - Start all or specific service
- `make down [service]` - Stop all or specific service  
- `make status [service]` - Check service status
- `make logs [service] [ARGS]` - View logs (use `ARGS="-f"` to follow)
- `make restart [service]` - Restart service
- `make clean [ARGS]` - Clean resources (use `ARGS="--all-volumes"` for full cleanup)
- `make network` - Create Docker networks
- `bash bash/tools/docker_repo.sh` - Test Docker registry performance

## Architecture
- **Core Script**: `bash/onestack.sh` - Central Docker Compose orchestration with parallel operations
- **Service Structure**: Each service in own directory with `docker-compose.yml`, `config/`, `data/`
- **Networks**: `web` (internet-facing via Traefik) and `internal_network` (service-to-service)
- **Shared Services**: PostgreSQL, MongoDB, Redis, Meilisearch, Chrome, ClickHouse under `shared/`
- **Reverse Proxy**: Traefik handles SSL termination, routing, service discovery
- **Tools**: 25+ services including AI tools (LibreChat, LiteLLM), productivity apps, databases

## Code Style & Conventions
- **Environment**: Global `.env` + per-service `.env` files for configuration
- **Service Exposure**: Use Traefik labels for web access: `traefik.http.routers.name.rule=Host(\`service.${BASE_DOMAIN}\`)`
- **Networks**: All web services join `web` network, internal services use `internal_network`
- **Health Checks**: Include health checks in docker-compose files using CMD-SHELL format
- **Naming**: Service directories match service names, use lowercase with hyphens
- **Security**: Never hardcode secrets, use environment variables, protect with basic auth where needed
