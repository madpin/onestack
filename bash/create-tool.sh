#!/bin/bash

# Script to create a new tool in OneStack
# Usage: bash/create-tool.sh <tool-name>

set -e

TOOL_NAME="$1"

if [ -z "$TOOL_NAME" ]; then
    echo "Error: Tool name is required"
    echo "Usage: bash/create-tool.sh <tool-name>"
    echo "Example: bash/create-tool.sh grafana"
    exit 1
fi

# Validate tool name (only lowercase letters, numbers, hyphens, underscores)
if ! [[ "$TOOL_NAME" =~ ^[a-z0-9_-]+$ ]]; then
    echo "Error: Tool name must contain only lowercase letters, numbers, hyphens, and underscores"
    exit 1
fi

TOOL_DIR="$TOOL_NAME"

# Load BASE_DOMAIN from root .env if it exists
if [ -f ".env" ]; then
    source .env
fi
BASE_DOMAIN="${BASE_DOMAIN:-onestack.madpin.dev}"

echo "Creating tool: $TOOL_NAME"

# Check if tool already exists
if [ -d "$TOOL_DIR" ]; then
    echo "Error: Tool directory '$TOOL_DIR' already exists"
    exit 1
fi

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p "$TOOL_DIR"/{config,data}

# Create .gitkeep files to ensure directories are tracked
touch "$TOOL_DIR/config/.gitkeep"

# Create .gitignore for the service
cat > "$TOOL_DIR/.gitignore" << EOF
# Ignore data directory (contains runtime data)
data/

# Keep .env files local (sensitive information)
.env
EOF

# Create docker-compose.yml template
echo "🐳 Creating docker-compose.yml..."
cat > "$TOOL_DIR/docker-compose.yml" << EOF
services:
  $TOOL_NAME:
    image: # TODO: Replace with actual image
    container_name: $TOOL_NAME
    restart: unless-stopped
    ports:
      - "8080:8080" # TODO: Replace with actual ports
    volumes:
      - ./data:/data
      - ./config:/config
    environment:
      # TODO: Add environment variables
      - ENV_VAR=value
    networks:
      - web
      - internal_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.$TOOL_NAME.rule=Host(\`$TOOL_NAME.\${BASE_DOMAIN}\`)"
      - "traefik.http.routers.$TOOL_NAME.entrypoints=websecure"
      - "traefik.http.services.$TOOL_NAME.loadbalancer.server.port=8080" # TODO: Replace with actual port

networks:
  web:
    external: true
    name: \${WEB_NETWORK_NAME}
  internal_network:
    external: true
    name: \${INTERNAL_NETWORK_NAME}
EOF

# Create .env template
echo "⚙️  Creating .env template..."
cat > "$TOOL_DIR/.env.template" << EOF
# onestack/$TOOL_NAME/.env.template
# Copy this file to .env and fill in your actual values

# -- Configuration --
# TODO: Add your configuration variables here
# Example:
# API_KEY=your-api-key-here
# DATABASE_URL=your-database-url

EOF

# Create .env file
cp "$TOOL_DIR/.env.template" "$TOOL_DIR/.env"

# Add TODO comment to .env
cat >> "$TOOL_DIR/.env" << EOF

# TODO: Fill in the actual values for your $TOOL_NAME configuration
EOF

echo "✅ Tool '$TOOL_NAME' created successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Edit $TOOL_DIR/docker-compose.yml to configure your service"
echo "2. Edit $TOOL_DIR/.env with your actual configuration"
echo "3. Add any configuration files to $TOOL_DIR/config/"
echo "4. Run 'make up' to start all services"
echo ""
echo "📁 Created structure:"
echo "  $TOOL_DIR/"
echo "  ├── docker-compose.yml"
echo "  ├── .env.template"
echo "  ├── .env"
echo "  ├── config/"
echo "  └── data/"
