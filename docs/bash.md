# OneStack Bash Scripts

This directory contains the core automation scripts that power OneStack's Docker service management. These scripts provide centralized, DRY (Don't Repeat Yourself) functionality for discovering, managing, and monitoring Docker Compose services across the entire stack.

## 📋 Table of Contents

- [Core Scripts](#-core-scripts)
- [Environment Management](#-environment-management)
- [Service Discovery](#-service-discovery)
- [Usage Examples](#-usage-examples)
- [Script Dependencies](#-script-dependencies)
- [Best Practices](#-best-practices)

## 🛠️ Core Scripts

### `env.sh` - Environment & Discovery Engine
**Central hub for environment loading and Docker Compose discovery**

**Key Functions:**
- `load_all_env_files()` - Loads all .env files from root and subdirectories
- `load_service_env_files()` - Loads environment for specific services
- `discover_compose_files()` - Auto-discovers all Docker Compose files
- `find_service_compose_file()` - Finds compose file for specific service
- `get_service_name()` - Extracts service name from compose file path

**Usage:**
```bash
source ./bash/env.sh
load_all_env_files
discover_compose_files
```

### `up.sh` - Service Startup
**Automatically discovers and starts all Docker Compose services**

**Features:**
- Auto-discovery of all docker-compose.yml files
- Network creation and validation
- Service dependency handling
- Detailed startup reporting
- Optional service filtering

**Usage:**
```bash
bash ./bash/up.sh                    # Start all services
bash ./bash/up.sh postgres           # Start only postgres
bash ./bash/up.sh "my service"       # Start service with spaces in name
```

### `down.sh` - Service Shutdown
**Gracefully stops all Docker Compose services in reverse order**

**Features:**
- Reverse-order shutdown for dependency management
- Orphaned container cleanup
- Comprehensive error reporting
- Optional service filtering

**Usage:**
```bash
bash ./bash/down.sh                  # Stop all services
bash ./bash/down.sh litellm          # Stop only litellm
```

### `restart.sh` - Service Restart
**Restarts services with proper environment reloading**

**Features:**
- Individual service restart
- Full stack restart
- Environment variable reloading
- Container and compose file support

**Usage:**
```bash
bash ./bash/restart.sh               # Restart all services
bash ./bash/restart.sh postgres      # Restart specific service
```

### `status.sh` - Service Status
**Displays comprehensive status of all services with color coding**

**Features:**
- Color-coded status display (Green: running, Yellow: stopped, Red: unhealthy)
- Service health information
- Formatted table output
- Legend for status interpretation

**Usage:**
```bash
bash ./bash/status.sh
```

### `logs.sh` - Log Management
**Advanced log viewing with filtering and following capabilities**

**Features:**
- Combined logs from all services
- Service-specific filtering
- Tail line control
- Follow mode for real-time logs
- Timestamp and service prefixes

**Usage:**
```bash
bash ./bash/logs.sh                          # Show recent logs from all services
bash ./bash/logs.sh -f                       # Follow all service logs
bash ./bash/logs.sh -s postgres              # Show postgres logs only
bash ./bash/logs.sh -t 50 -f                 # Follow last 50 lines
bash ./bash/logs.sh -s litellm -f            # Follow litellm logs
```

**Options:**
- `-f, --follow` - Follow log output in real-time
- `-t, --tail LINES` - Number of lines to show (default: 100)
- `-s, --service NAME` - Filter logs for specific service
- `-h, --help` - Show usage information

### `network.sh` - Network Management
**Creates and manages Docker networks from environment variables**

**Features:**
- Auto-discovery of network variables from .env files
- Network existence checking
- Batch network creation
- Support for multiple network patterns

**Usage:**
```bash
bash ./bash/network.sh
```

**Environment Variables Detected:**
- `WEB_NETWORK_NAME` - Primary network
- Any variable matching `*NETWORK*` pattern

### `clean.sh` - System Cleanup
**Comprehensive cleanup of services, networks, and Docker resources**

**Features:**
- Graceful service shutdown
- Network removal
- Orphaned container cleanup
- Unused volume pruning
- Resource usage reporting

**Usage:**
```bash
bash ./bash/clean.sh
```

**Cleanup Actions:**
1. Stop all services using `down.sh`
2. Remove custom networks
3. Prune unused containers
4. Remove anonymous volumes
5. Clean unused networks

### `create-tool.sh` - Tool Creation
**Creates new tool services with web interfaces**

**Features:**
- Directory structure creation
- Docker Compose template with Traefik labels
- Environment file templates
- Web-accessible service configuration

**Usage:**
```bash
bash ./bash/create-tool.sh grafana
```

**Creates:**
```
grafana/
├── docker-compose.yml    # Traefik-enabled service
├── .env.template         # Environment template
├── .env                  # Local environment
├── config/               # Configuration files
└── data/                 # Persistent data
```

### `create-shared.sh` - Shared Service Creation
**Creates new shared infrastructure services**

**Features:**
- Internal service templates
- No Traefik exposure by default
- Database and backend service patterns
- Standardized directory structure

**Usage:**
```bash
bash ./bash/create-shared.sh elasticsearch
```

**Creates:**
```
shared/elasticsearch/
├── docker-compose.yml    # Internal service
├── .env.template         # Environment template
├── .env                  # Local environment
├── config/               # Configuration files
└── data/                 # Persistent data
```

## 🔧 Environment Management

### Environment Loading Strategy

1. **Root .env** - Loaded first, contains global configuration
2. **Service .env** - Service-specific overrides and secrets
3. **Runtime Variables** - Dynamically discovered networks and services

### Environment File Hierarchy

```
.env                           # Global configuration
├── traefik/.env              # Traefik-specific config
├── litellm/.env              # LiteLLM API keys and config
├── karakeep/.env             # Karakeep application config
└── shared/
    ├── postgres/.env         # PostgreSQL credentials
    ├── redis/.env            # Redis configuration
    └── mongodb/.env          # MongoDB setup
```

## 🔍 Service Discovery

### Discovery Patterns

The scripts automatically discover services using these patterns:

1. **Direct Services:** `./service-name/docker-compose.yml`
2. **Shared Services:** `./shared/service-name/docker-compose.yml`
3. **Variant Files:** `docker-compose.yaml`, `docker-compose.*.yml`

### Discovery Filtering

Services can be filtered during discovery:

```bash
discover_compose_files "postgres"        # Find postgres service only
discover_compose_files "" "false"        # Exclude shared/ directory
discover_compose_files "litellm" "true"  # Include shared, filter litellm
```

## 📚 Usage Examples

### Complete Stack Management

```bash
# Start the entire stack
make up

# Check all service status
make status

# View combined logs
make logs

# Follow logs from specific service
make logs-postgres ARGS='-f'

# Clean shutdown and cleanup
make clean
```

### Individual Service Management

```bash
# Start specific service
bash ./bash/up.sh postgres

# Restart service and view logs
bash ./bash/restart.sh litellm
bash ./bash/logs.sh -s litellm -f

# Stop specific service
bash ./bash/down.sh karakeep
```

### Development Workflow

```bash
# Create new tool
bash ./bash/create-tool.sh monitoring

# Edit configuration
# vim monitoring/.env
# vim monitoring/docker-compose.yml

# Test the service
bash ./bash/up.sh monitoring
bash ./bash/logs.sh -s monitoring -f

# Full restart if needed
bash ./bash/restart.sh monitoring
```

## 🔗 Script Dependencies

### Dependency Graph

```
env.sh (core)
├── up.sh
├── down.sh
├── restart.sh
├── status.sh
├── logs.sh
├── network.sh
└── clean.sh
    └── down.sh
```

### External Dependencies

- **Docker & Docker Compose** - Container orchestration
- **Bash 4.0+** - Script execution environment
- **GNU Utils** - `find`, `grep`, `cut`, standard utilities

## 📖 Best Practices

### Script Usage Guidelines

1. **Always source env.sh first:**
   ```bash
   source ./bash/env.sh
   load_all_env_files
   ```

2. **Use centralized discovery:**
   ```bash
   discover_compose_files
   # Use $compose_files array
   ```

3. **Handle errors gracefully:**
   ```bash
   if ! load_all_env_files; then
       echo "Failed to load environment"
       exit 1
   fi
   ```

4. **Prefer Make targets for user interaction:**
   ```bash
   make up        # Instead of bash ./bash/up.sh
   make logs      # Instead of bash ./bash/logs.sh
   ```

### Development Guidelines

1. **Add new functionality to env.sh** for reusability
2. **Follow the established error handling patterns**
3. **Use consistent output formatting** (✅ ❌ ⚠️ emojis)
4. **Document new functions** in this README
5. **Test scripts with various service configurations**

### Troubleshooting

**Common Issues:**

1. **Network creation fails:**
   ```bash
   # Check environment variables
   source ./bash/env.sh && load_all_env_files
   echo $WEB_NETWORK_NAME
   ```

2. **Service discovery returns empty:**
   ```bash
   # Verify compose files exist
   find . -name "docker-compose*.yml" -type f
   ```

3. **Environment loading fails:**
   ```bash
   # Check .env file permissions and syntax
   ls -la .env
   cat .env | grep -v '^#' | grep '='
   ```

---

**OneStack Bash Scripts** - Powering infrastructure automation with simplicity and reliability 🚀