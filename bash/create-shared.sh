#!/bin/bash

# Script to create a new shared service in OneStack
# Usage: bash/create-shared.sh <service-name>

set -e

SERVICE_NAME="$1"

if [ -z "$SERVICE_NAME" ]; then
    echo "Error: Service name is required"
    echo "Usage: bash/create-shared.sh <service-name>"
    echo "Example: bash/create-shared.sh mongodb"
    exit 1
fi

# Validate service name (only lowercase letters, numbers, hyphens, underscores)
if ! [[ "$SERVICE_NAME" =~ ^[a-z0-9_-]+$ ]]; then
    echo "Error: Service name must contain only lowercase letters, numbers, hyphens, and underscores"
    exit 1
fi

SHARED_DIR="shared/$SERVICE_NAME"

echo "Creating shared service: $SERVICE_NAME"

# Check if service already exists
if [ -d "$SHARED_DIR" ]; then
    echo "Error: Shared service directory '$SHARED_DIR' already exists"
    exit 1
fi

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p "$SHARED_DIR"/{config,data}

# Create .gitkeep files to ensure directories are tracked
touch "$SHARED_DIR/config/.gitkeep"

# Create .gitignore for the service
cat > "$SHARED_DIR/.gitignore" << EOF
# Ignore data directory (contains runtime data)
data/

# Keep .env files local (sensitive information)
.env
EOF

# Create docker-compose.yml template
echo "🐳 Creating docker-compose.yml..."
cat > "$SHARED_DIR/docker-compose.yml" << EOF
services:
  $SERVICE_NAME:
    image: # TODO: Replace with actual image
    container_name: $SERVICE_NAME
    restart: unless-stopped
    ports:
      - "5432:5432" # TODO: Replace with actual ports
    volumes:
      - ./data:/var/lib/data # TODO: Adjust volume paths
      - ./config:/etc/config # TODO: Adjust config paths
    environment:
      # TODO: Add environment variables
      - ENV_VAR=value
    networks:
      - internal_network
    healthcheck:
      test: ["CMD-SHELL", "echo 'Health check command here'"] # TODO: Replace with actual health check
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  internal_network:
    external: true
    name: \${WEB_NETWORK_NAME}
EOF

# Create .env template
echo "⚙️  Creating .env template..."
cat > "$SHARED_DIR/.env.template" << EOF
# onestack/shared/$SERVICE_NAME/.env.template
# Copy this file to .env and fill in your actual values

# -- Configuration --
# TODO: Add your configuration variables here
# Example:
# DB_USER=your-username
# DB_PASSWORD=your-secure-password
# DB_NAME=your-database-name

EOF

# Create .env file
cp "$SHARED_DIR/.env.template" "$SHARED_DIR/.env"

# Add TODO comment to .env
cat >> "$SHARED_DIR/.env" << EOF

# TODO: Fill in the actual values for your $SERVICE_NAME configuration
EOF

echo "✅ Shared service '$SERVICE_NAME' created successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Edit $SHARED_DIR/docker-compose.yml to configure your service"
echo "2. Edit $SHARED_DIR/.env with your actual configuration"
echo "3. Add any configuration files to $SHARED_DIR/config/"
echo "4. Run 'make up' to start all services"
echo ""
echo "📁 Created structure:"
echo "  $SHARED_DIR/"
echo "  ├── docker-compose.yml"
echo "  ├── .env.template"
echo "  ├── .env"
echo "  ├── config/"
echo "  └── data/"
echo ""
echo "ℹ️  Note: Shared services are internal and don't expose public web interfaces by default."
echo "   If you need web access, consider creating a tool instead with 'make create-tool'."
