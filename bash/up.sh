#!/bin/bash

# Auto Up Script
# Automatically discovers and starts all Docker Compose services

# Navigate to the project root
cd "$(dirname "$0")/.."

source ./bash/env.sh

# Load all environment variables
load_all_env_files || exit 1

echo "=== OneStack Auto Startup ==="

# Ensure networks exist
echo ""
echo "Ensuring networks are created..."
if ! bash ./bash/network.sh; then
    echo "✗ Network setup failed"
    exit 1
fi

# Parse optional service/folder argument(s)
SERVICE_ARG="$1"

# If more than one argument, join them with space (for multi-word folder names)
if [ $# -gt 1 ]; then
    shift
    SERVICE_ARG="$SERVICE_ARG $*"
fi

# Auto-discover Docker Compose files
echo ""
discover_compose_files "$SERVICE_ARG"
if ! print_discovered_files "Discovering Docker Compose files..."; then
    echo "✗ No Docker Compose files found!"
    exit 1
fi

# Start all services
echo ""
echo "Starting services..."
failed_services=0
successful_services=0

for compose_file in "${compose_files[@]}"; do
    service_name=$(get_service_name "$compose_file")
    
    echo ""
    echo "🚀 Starting service: $service_name ($compose_file)"
    
    if docker compose -f "$compose_file" up -d; then
        echo "✅ $service_name started successfully"
        ((successful_services++))
    else
        echo "❌ Failed to start $service_name"
        ((failed_services++))
    fi
done

# Summary
echo ""
echo "=== Startup Summary ==="
echo "Successfully started: $successful_services service(s)"
echo "Failed to start: $failed_services service(s)"

if [ $failed_services -gt 0 ]; then
    echo ""
    echo "⚠️  Some services failed to start. Check the logs above for details."
    exit 1
else
    echo ""
    echo "🎉 All services are up and running!"
    echo ""
    echo "Use 'make logs' to view service logs"
    echo "Use 'make down' to stop all services"
fi
