#!/bin/bash

# Auto Down Script
# Automatically discovers and stops all Docker Compose services

# Navigate to the project root
cd "$(dirname "$0")/.."

source ./bash/env.sh

# Load all environment variables (needed for proper shutdown)
load_all_env_files || exit 1

echo "=== OneStack Auto Shutdown ==="

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
    echo "Nothing to stop."
    exit 0
fi

# Stop all services (in reverse order for dependencies)
echo ""
echo "Stopping services..."
failed_services=0
successful_services=0

# Reverse the array to stop services in reverse order
for ((i=${#compose_files[@]}-1; i>=0; i--)); do
    compose_file="${compose_files[i]}"
    service_name=$(get_service_name "$compose_file")
    
    echo ""
    echo "🛑 Stopping service: $service_name ($compose_file)"
    
    if docker compose -f "$compose_file" down; then
        echo "✅ $service_name stopped successfully"
        ((successful_services++))
    else
        echo "❌ Failed to stop $service_name"
        ((failed_services++))
    fi
done

# Additional cleanup: remove orphaned containers
echo ""
echo "Cleaning up orphaned containers..."
docker container prune -f >/dev/null 2>&1

# Summary
echo ""
echo "=== Shutdown Summary ==="
echo "Successfully stopped: $successful_services service(s)"
echo "Failed to stop: $failed_services service(s)"

if [ $failed_services -gt 0 ]; then
    echo ""
    echo "⚠️  Some services failed to stop. Check the logs above for details."
    echo "You may need to stop them manually with 'docker ps' and 'docker stop'"
    exit 1
else
    echo ""
    echo "🏁 All services have been stopped successfully!"
fi
