#!/bin/bash

# Auto Network Management Script
# Automatically loads environment variables and creates networks

# Navigate to the project root
cd "$(dirname "$0")/.."

source ./bash/env.sh

# Load environment variables from all .env files
load_all_env_files || exit 1

echo "=== Auto Network Management ==="

# Function to create network if it doesn't exist
create_network() {
    local network_name="$1"
    if [ -z "$network_name" ]; then
        echo "Warning: Network name is empty, skipping..."
        return 1
    fi
    
    if docker network ls --format "{{.Name}}" | grep -q "^${network_name}$"; then
        echo "✓ Network '$network_name' already exists"
        return 0
    else
        echo "Creating network: $network_name"
        if docker network create "$network_name"; then
            echo "✓ Network '$network_name' created successfully"
            return 0
        else
            echo "✗ Failed to create network '$network_name'"
            return 1
        fi
    fi
}

# Create networks from environment variables
networks_created=0

# Check for WEB_NETWORK_NAME (primary network)
if [ ! -z "$WEB_NETWORK_NAME" ]; then
    if create_network "$WEB_NETWORK_NAME"; then
        ((networks_created++))
    fi
fi

# Check for additional network variables (common patterns)
for var in $(env | grep -E '^[A-Z_]*NETWORK[A-Z_]*=' | cut -d= -f1); do
    network_value=$(eval echo \$$var)
    if [ "$var" != "WEB_NETWORK_NAME" ] && [ ! -z "$network_value" ]; then
        echo "Found additional network variable: $var=$network_value"
        if create_network "$network_value"; then
            ((networks_created++))
        fi
    fi
done

echo ""
echo "=== Network Summary ==="
echo "Networks processed: $networks_created"
if [ $networks_created -eq 0 ]; then
    echo "No networks were created. Please check your .env files for WEB_NETWORK_NAME."
    exit 1
fi

echo "Network setup completed successfully!"
