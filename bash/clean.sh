#!/bin/bash

# Auto Clean Script
# Automatically stops all services and cleans up networks and resources

# Navigate to the project root
cd "$(dirname "$0")/.."

source ./bash/env.sh

echo "=== OneStack Auto Cleanup ==="

# First stop all services
echo "Stopping all services..."
if ! bash ./bash/down.sh; then
    echo "Warning: Some services may not have stopped properly"
fi

echo ""
echo "Performing additional cleanup..."

# Load all environment variables to get network names (down.sh already loaded them, but we need them here)
load_all_env_files || exit 1

# Clean up networks
echo "Cleaning up networks..."
networks_removed=0

# Remove primary network
if [ ! -z "$WEB_NETWORK_NAME" ]; then
    if docker network ls --format "{{.Name}}" | grep -q "^${WEB_NETWORK_NAME}$"; then
        echo "Removing network: $WEB_NETWORK_NAME"
        if docker network rm "$WEB_NETWORK_NAME" 2>/dev/null; then
            echo "✅ Network '$WEB_NETWORK_NAME' removed"
            ((networks_removed++))
        else
            echo "⚠️  Could not remove network '$WEB_NETWORK_NAME' (may still be in use)"
        fi
    else
        echo "Network '$WEB_NETWORK_NAME' not found (already removed or never created)"
    fi
fi

# Remove additional networks
for var in $(env | grep -E '^[A-Z_]*NETWORK[A-Z_]*=' | cut -d= -f1); do
    network_value=$(eval echo \$$var)
    if [ "$var" != "WEB_NETWORK_NAME" ] && [ ! -z "$network_value" ]; then
        if docker network ls --format "{{.Name}}" | grep -q "^${network_value}$"; then
            echo "Removing additional network: $network_value"
            if docker network rm "$network_value" 2>/dev/null; then
                echo "✅ Network '$network_value' removed"
                ((networks_removed++))
            else
                echo "⚠️  Could not remove network '$network_value' (may still be in use)"
            fi
        fi
    fi
done

# Clean up unused Docker resources
echo ""
echo "Cleaning up unused Docker resources..."

# Remove unused containers
echo "Removing unused containers..."
docker container prune -f

# Remove unused volumes (be careful with this)
echo "Removing unused anonymous volumes..."
docker volume prune -f

# Remove unused networks (excluding the ones we tried to remove above)
echo "Removing unused networks..."
docker network prune -f

# Remove unused images (optional - uncomment if desired)
# echo "Removing unused images..."
# docker image prune -f

echo ""
echo "=== Cleanup Summary ==="
echo "Networks removed: $networks_removed"
echo ""
echo "🧹 Cleanup completed!"
echo ""
echo "Note: Named volumes and custom images were preserved."
echo "Use 'docker system prune -a --volumes' for more aggressive cleanup (⚠️  destructive)"
