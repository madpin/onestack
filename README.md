# My OneStack Server Setup!

This is the home for my personal OneStack deployment – a Docker-based infrastructure I use to run a bunch of self-hosted services. It's all neatly managed with automatic SSL, a reverse proxy, and more!

**GitHub Repository:** [https://github.com/madpin/onestack](https://github.com/madpin/onestack)

## 🚀 Welcome to My OneStack!

Hey there! This isn't just any OneStack; it's *my* personal command center, a lovingly curated collection of self-hosted tools and services, all humming away on a rather beefy **Oracle Cloud ARM VPS**. We're talking **24GB of RAM** and **4 vCPUs** – plenty of juice to run all sorts of cool stuff!

**What's the Big Idea?**

I wanted a simple, reproducible, and fun way to manage my digital world. This OneStack setup, built on Docker, lets me:

- 🚀 **Launch new services in a snap:** Thanks to templating and some handy `Makefile` magic.
- 🔒 **Keep things secure:** With automatic SSL from Traefik and sensible network setups.
- 🛠️ **Tinker without fear:** Experimenting with new tools without (hopefully!) breaking the important stuff.
- 🌐 **Access my tools from anywhere:** Securely, of course!
- 🤓 **Learn and grow:** Because what's a home lab for if not for playing with new tech and figuring things out?

This repository is how I manage it all. It's a bit like my digital workshop, where I can spin up new tools, try out different configurations, and generally have a good time managing my own little corner of the internet.

**Think of this as a personal journey into self-hosting, and you're invited to peek behind the curtain!**

While the original OneStack provides a solid foundation for a production-ready Docker infrastructure, this version is tailored to my needs and experiments. It still benefits from core OneStack features like:

- Automatic SSL certificates via Let's Encrypt (thanks, Traefik!)
- Reverse proxying with automatic service discovery
- Centralized environment management (mostly DRY!)
- Internal and external network segregation
- Automated service management via `Makefile`

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Makefile Commands](#-makefile-commands)
- [Creating New Services](#-creating-new-services)
- [Available Tools](#-available-tools)
- [Shared Services](#-services)
- [Traefik & Security](#-traefik--security)
- [Environment Configuration](#-environment-configuration)
- [Network Architecture](#-network-architecture)

## 🚀 Quick Start

1. **Clone and setup environment:**
   ```bash
   git clone https://github.com/madpin/onestack.git
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

The Makefile provides centralized management for the entire stack using the `bash/onestack.sh` script.

- **`make help`**: Shows this help message with all available commands and examples.

- **`make network`**:
  Creates all Docker networks defined in your `.env` files (e.g., `WEB_NETWORK_NAME`). This is usually run once initially or if network configurations change.

- **`make up [service]`**:
  Starts all services or a specific `[service]` if provided (e.g., `make up traefik`). This involves pulling/building images and then starting the containers.

- **`make down [service]`**:
  Stops all services or a specific `[service]` (e.g., `make down traefik`).

- **`make restart [service]`**:
  Restarts all services or a specific `[service]` by first stopping and then starting them.

- **`make clean [ARGS...]`**:
  Stops all services and cleans up Docker resources.
  - By default, removes stopped containers, defined networks, and unused anonymous volumes.
  - `ARGS` can be used to pass options like:
    - `make clean ARGS=--all-volumes`: Prompts to remove all unused volumes (including named ones).
    - `make clean ARGS=--remove-dangling-images`: Removes dangling images.
    - `make clean ARGS=--remove-images`: Removes all unused images.

- **`make logs [service] [ARGS...]`**:
  Shows logs for all services or a specific `[service]`.
  - `ARGS` are passed directly to the `docker compose logs` command.
  - Examples:
    - `make logs`: Show recent logs from all services.
    - `make logs traefik`: Show recent logs from `traefik`.
    - `make logs ARGS="-f"`: Follow logs from all services.
    - `make logs homepage ARGS="--tail 50 -f"`: Follow last 50 log lines from `homepage`.

- **`make logs-SERVICE [ARGS...]`**:
  A shortcut to show logs for a specific `SERVICE`.
  - Example: `make logs-postgres ARGS="-f"` is equivalent to `make logs postgres ARGS="-f"`.

- **`make logsf SERVICE`**:
  A shortcut to follow logs for a specific `SERVICE`.
  - Example: `make logsf traefik` is equivalent to `make logs traefik ARGS="-f"`.

- **`make status`**:
  Shows the status of all services (running, stopped, health).

- **`make create-tool NAME=...`**:
  Creates a new tool template directory.
  - Example: `make create-tool NAME=my-new-app`

- **`make create-shared NAME=...`**:
  Creates a new shared service template directory.
  - Example: `make create-shared NAME=my-new-db`

**Notes on Usage:**
- The `[service]` argument usually refers to the directory name of the service (e.g., `traefik`, `homepage`, `shared/postgres`).
- The `ARGS` variable allows passing additional command-line arguments to the underlying `bash/onestack.sh` script and subsequently to `docker compose` commands.
- To load environment variables into your *current shell* (e.g., for direct `docker` CLI use), you need to `source` the `.env` files: `source .env` or `source <service>/.env`. The `make reload` command has been removed as it cannot affect the parent shell.

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

## 🧰 What's Running in My Digital Playground?

This is where the magic happens! Here's a rundown of the cool tools and services I've got running on my Oracle Cloud VPS. Each one has its own little job to do, making my digital life smoother, more fun, or just more interesting.

| Service Icon | Name & Link | What it Does (for me!) | Why I Run It / My Use Case | Tech Stack Highlights |
| :----------: | ----------- | ---------------------- | -------------------------- | :-------------------: |
| 🏠 | **Homepage** (`homepage.${BASE_DOMAIN}`) | My personal dashboard & new tab page. | Quick access to all my other services. It's the front door to my digital kingdom! | Static site, YAML config |
| 🧠 | **Karakeep** (`karakeep.${BASE_DOMAIN}`) | My digital brain for notes, bookmarks, and knowledge. | Capturing ideas, articles, and anything I want to remember or find later. Essential for my research and learning. | PostgreSQL, Redis, Chrome, LiteLLM |
| 🤖💬 | **LiteLLM** (`litellm.${BASE_DOMAIN}`) | A central hub for talking to various AI models. | Experimenting with different LLMs without juggling a million APIs. Powers AI features in other tools. | Python, PostgreSQL, Redis |
| 💬 | **LibreChat** (`librechat.${BASE_DOMAIN}`) | An open-source AI chat interface. | My private ChatGPT-like instance. Great for drafting, brainstorming, and getting quick answers. | MongoDB, Meilisearch (optional) |
| 🤩 | **LobeChat** (`lobechat.${BASE_DOMAIN}`) | Another slick AI chat interface with a focus on plugins and a great UI. | Trying out different AI chat experiences and exploring its plugin ecosystem. | Next.js |
| 🖼️ | **OpenWebUI** (`openwebui.${BASE_DOMAIN}`) | A user-friendly web UI for various LLMs, similar to ChatGPT. | More AI experimentation! I like its interface and ability to connect to different backends. | Docker, Python |
| ⚙️ | **n8n** (`n8n.${BASE_DOMAIN}`) | Workflow automation for all the things! | Connecting different apps and services, automating repetitive tasks. My digital duct tape! | Node.js, Vue.js |
| 🗂️ | **Organizr** (`organizr.${BASE_DOMAIN}`) | A web-based manager for all your self-hosted services. | Another way to get a quick overview and access to my services, with a focus on HTPC setups but useful generally. | PHP, Nginx |
| 📄 | **Stirling PDF** (`stirling.${BASE_DOMAIN}`) | My go-to for all PDF manipulations. | Merging, splitting, converting, OCRing PDFs without uploading them to random websites. Super handy! | Java, Spring Boot |
| 📰 | **Tiny Tiny RSS (TTRSS)** (`ttrss.${BASE_DOMAIN}`) | My personal RSS feed reader. | Keeping up with blogs, news, and project updates without getting lost in social media. | PHP, PostgreSQL |
| --- | --- | --- | --- | --- |
| 🚪 | **Traefik Dashboard** (`traefik.${BASE_DOMAIN}` or `${BASE_DOMAIN}`) | The control panel for my reverse proxy. | Not a "tool" I use daily, but essential for seeing how traffic is routed and managing SSL. | Go |
| 🐳 | **Portainer** (`portainer.${BASE_DOMAIN}`) | Docker container management GUI. | Easy way to check on my containers, view logs, and manage Docker resources without always hitting the CLI. | Go, Vue.js |
| 🔄 | **Watchtower** (No Web UI) | Keeps my Docker containers updated automatically. | Set-it-and-forget-it updates for many of my services. Keeps things fresh and secure! | Go |
| 🗃️ | **DBGate** (`dbgate.${BASE_DOMAIN}`) | Web-based database manager. | Quick and easy way to peek into my PostgreSQL or MongoDB databases, run queries, and manage data. | Node.js |

**A Note on Dependencies:** Many of these tools rely on the "Shared Services" I describe below (like PostgreSQL, Redis, etc.). They work together to create a cohesive little ecosystem!

## 🏗️ The Unsung Heroes: Shared Backstage Crew!

Think of these as the hardworking backstage crew for my digital tools. They're the databases, caches, and other essential bits that many of the fun tools listed above need to function. They might not have flashy web UIs, but they're the backbone of this whole operation!

Here’s who’s in the crew:

-   💾 **PostgreSQL (`postgres:5432`):** My trusty relational database. It's like a super organized filing cabinet for structured data. Many apps use this, especially with the `pgvector` extension for cool AI-powered similarity searches!
-   📄 **MongoDB (`mongodb:27017`):** A flexible document database. Great for when data is less structured, like with chat logs or user profiles. LibreChat is a big fan of this one.
-   ⚡ **Redis (`redis:6379`):** An incredibly fast in-memory cache and message broker. It helps speed things up by keeping frequently accessed data ready to go in a flash and assists with background tasks.
-   🔎 **Meilisearch (`meilisearch:7700`):** A blazing-fast, typo-tolerant search engine. Makes finding things in apps like LibreChat a breeze.
-   🌐 **Headless Chrome (`chrome:9222`):** A full web browser, but without the visual interface. Karakeep uses this under the hood for things like web scraping and taking webpage snapshots.
-   📊 **ClickHouse (`clickhouse:8123`):** A super-fast columnar database built for analytics. If I ever need to crunch serious numbers or analyze large datasets from my tools, this is where it'll happen.
-   🕵️ **SearXNG (`searxng.${BASE_DOMAIN}`):** My own private, privacy-respecting metasearch engine. It aggregates results from many search providers without tracking me. Can be configured to be private or public.
-   🛡️ **Tailscale (VPN):** Not a database or cache, but a critical networking hero! It creates a secure, private network (a "tailnet") over the internet, making it easy and safe for my services to talk to each other, and for me to access them securely from anywhere.

### Quick Reference: Shared Service Details

This table gives a bit more technical detail on these core components:

| Service     | Default Internal Port | Key Purpose(s)                                  | Typical Docker Image (may vary)       |
| :---------- | :-------------------- | :---------------------------------------------- | :------------------------------------ |
| PostgreSQL  | 5432                  | Relational data storage, vector similarity      | `pgvector/pgvector:pg17`              |
| MongoDB     | 27017                 | Document data storage (NoSQL)                   | `mongo:8.0`                           |
| Redis       | 6379                  | Caching, session storage, message queuing       | `redis:alpine`                        |
| Meilisearch | 7700                  | Fast full-text search                           | `getmeili/meilisearch:v1.15`          |
| Chrome      | 9222                  | Headless web browsing, scraping, screenshots    | `gcr.io/zenika-hub/alpine-chrome:123` |
| ClickHouse  | 8123                  | High-performance analytical queries             | `clickhouse/clickhouse-server`        |
| SearXNG     | 8080 (internal)       | Private metasearch engine                       | `searxng/searxng`                     |
| Tailscale   | N/A (network layer)   | Secure private networking (VPN)                 | `tailscale/tailscale`                 |

*(Internal ports are what services use to talk to each other. External access is usually via Traefik and a domain name, if applicable.)*

### A Bit More on Databases

-   **PostgreSQL:** This setup includes the `pgvector` extension, which is awesome for AI applications that need to find similar items based on "embeddings" (fancy math representations of data). Initialization scripts in `/docker-entrypoint-initdb.d` can pre-load schemas or data.
-   **MongoDB:** Configured for a single user that can access multiple databases (like `librechat` and a general `madpin` database). User creation is handled automatically by an init script.

These shared services are defined in the `shared/` directory. Each has its own `docker-compose.yml` and README, so check those out if you want to dive deeper into their specific configurations!

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

---

## 📚 Additional Resources

- **Traefik Documentation:** [Official Traefik Docs](https://doc.traefik.io/traefik/)
- **Docker Compose Reference:** [Docker Compose Docs](https://docs.docker.com/compose/)
- **Let's Encrypt:** [SSL Certificate Documentation](https://letsencrypt.org/docs/)

## ✍️ Author

This project is maintained by **madpin**.

- **Website:** [madpin.dev](https://madpin.dev)
- **GitHub:** [madpin](https://github.com/madpin)

## 🤝 Contributing

1. Follow the established directory structure
2. Include proper environment templates
3. Add Traefik labels for web services
4. Include health checks
5. Update this README with new services

---

**OneStack** - Simplifying self-hosted infrastructure management 🚀