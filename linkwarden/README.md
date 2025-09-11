# Linkwarden

## Overview

Linkwarden is a collaborative bookmark manager designed to collect, organize, and preserve webpages. It features automatic screenshot capturing, PDF generation, full-text search, tag-based organization, and AI-powered tagging capabilities.

Key features:
- **Collaborative bookmark management** with collections and sharing
- **Automatic preservation** of webpages (screenshots, PDFs, readable text)
- **Full-text search** powered by Meilisearch
- **AI-powered tagging** for automatic organization
- **Browser extension** support for easy saving
- **RSS feed generation** for collections
- **Import/Export** from various bookmark formats

## Requirements

- Docker and Docker Compose
- OneStack shared services:
  - PostgreSQL (for data storage)
  - Meilisearch (for search functionality)
  - LiteLLM (for AI features)
- Traefik (for reverse proxy and SSL)

## Dependencies

- **PostgreSQL:** Stores user data, bookmarks, collections, and metadata
- **Meilisearch:** Provides full-text search capabilities across bookmarks
- **LiteLLM:** Powers AI tagging and content analysis features
- **Traefik:** Handles routing and SSL termination

## Configuration

### Environment Variables

The service uses a two-tier configuration system:
1. **Global variables** from `../../.env` (database, networks, domains)
2. **Service-specific variables** from `.env` (API keys, feature toggles)

Key variables to configure in `.env`:

```bash
# Required: Generate a secure random string (32+ characters)
LINKWARDEN_NEXTAUTH_SECRET=your-very-long-secret-string

# Required: API key for AI features (obtained from LiteLLM)
OPENAI_API_KEY_LINKWARDEN=sk-your-litellm-api-key

# Optional: Control user registration
LINKWARDEN_DISABLE_REGISTRATION=false

# Optional: Limit links per user
LINKWARDEN_MAX_LINKS_PER_USER=1000
```

### Database Setup

Linkwarden requires a PostgreSQL database named `linkwarden`. This will be created automatically when the service starts if it doesn't exist.

### AI Features

AI tagging is configured to use OneStack's LiteLLM service by default. The service will automatically tag bookmarks based on their content. Ensure LiteLLM is running and you have a valid API key.

## Usage

### Starting the Service

```bash
# From the OneStack root directory
make up linkwarden

# Or from this directory
docker compose up -d
```

### Accessing Linkwarden

Once running, access Linkwarden at: `https://linkwarden.${BASE_DOMAIN}`

### Initial Setup

1. Create your first account (if registration is enabled)
2. Install the browser extension for easy bookmark saving
3. Configure AI tagging in settings if desired
4. Start organizing your bookmarks into collections

### Browser Extension

Install the official Linkwarden browser extension from:
- [Chrome Web Store](https://chrome.google.com/webstore/detail/linkwarden/pnkhbahbobmpdagabjlcmbanbinjgoog)
- [Firefox Add-ons](https://addons.mozilla.org/en-US/firefox/addon/linkwarden/)

Configure the extension to point to your Linkwarden instance URL.

### Features Overview

- **Collections:** Organize bookmarks into themed groups
- **Tags:** Add custom or AI-generated tags for easy filtering
- **Search:** Full-text search across all saved content
- **Preservation:** Automatic screenshots and PDF generation
- **Sharing:** Share collections publicly or with specific users
- **Import:** Bulk import from browsers and other bookmark managers

## Troubleshooting

### Common Issues

**Service won't start:**
- Ensure PostgreSQL and Meilisearch are running: `make status`
- Check if the database is accessible: `make logs linkwarden`

**AI tagging not working:**
- Verify LiteLLM is running: `make status litellm`
- Check API key configuration in `.env`
- Ensure the API key has sufficient credits/permissions

**Search not working:**
- Verify Meilisearch is running: `make status meilisearch`
- Check Meilisearch logs: `make logs meilisearch`

**Browser extension can't connect:**
- Verify the Linkwarden URL is accessible
- Check CORS settings if using a custom domain
- Ensure SSL certificates are valid

### Logs

View service logs:
```bash
# All linkwarden logs
make logs linkwarden

# Follow logs in real-time
make logsf linkwarden

# Last 100 lines
make logs linkwarden ARGS="--tail=100"
```

### Database Access

Access the database for debugging:
```bash
# Open PostgreSQL shell
make shell-postgres

# Connect to linkwarden database
\c linkwarden
```

### Storage

Linkwarden stores files in `./data/` directory:
- Screenshots of saved pages
- PDF versions of pages
- User avatars
- Temporary files

Ensure this directory has proper permissions (UID:GID from global `.env`).
