#!/bin/bash

# Auto Down Script - Parallel Edition
# Automatically discovers and stops all Docker Compose services in parallel

# Navigate to the project root
cd "$(dirname "$0")/.."

source ./bash/env.sh

# Load all environment variables (needed for proper shutdown)
load_all_env_files || exit 1

echo "=== OneStack Auto Shutdown (Parallel) ==="

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

# Configuration for parallel execution
MAX_PARALLEL_JOBS=6  # Maximum number of services to stop simultaneously
SHUTDOWN_TIMEOUT=60  # Timeout in seconds for each service shutdown
TEMP_DIR="/tmp/onestack-shutdown-$$"
mkdir -p "$TEMP_DIR"

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Function to stop a single service and log results
stop_service_with_logging() {
    local compose_file="$1"
    local service_name="$2"
    local log_file="$TEMP_DIR/$service_name.log"
    local status_file="$TEMP_DIR/$service_name.status"
    
    # Initialize status file
    echo "RUNNING" > "$status_file"
    
    # Stop service quietly, only log errors
    if timeout "$SHUTDOWN_TIMEOUT" docker compose -f "$compose_file" down > "$log_file" 2>&1; then
        echo "SUCCESS" > "$status_file"
        echo "✅ $service_name stopped successfully"
    else
        echo "FAILED" > "$status_file"
        echo "❌ $service_name failed to stop (timeout or error)"
        # Show detailed logs for failed services
        echo "   Error details:"
        cat "$log_file" | sed 's/^/   /'
    fi
}

# Simple parallel execution with job control
echo ""
echo "Stopping services in parallel (max $MAX_PARALLEL_JOBS concurrent, ${SHUTDOWN_TIMEOUT}s timeout)..."

failed_services=0
successful_services=0
active_jobs=0

# Process services in reverse order
for ((i=${#compose_files[@]}-1; i>=0; i--)); do
    compose_file="${compose_files[i]}"
    service_name=$(get_service_name "$compose_file")
    
    # Wait if we have too many active jobs
    while [ $active_jobs -ge $MAX_PARALLEL_JOBS ]; do
        wait -n  # Wait for any background job to complete
        ((active_jobs--))
    done
    
    # Start the service shutdown in background
    stop_service_with_logging "$compose_file" "$service_name" &
    ((active_jobs++))
done

# Wait for all remaining jobs to complete
while [ $active_jobs -gt 0 ]; do
    wait -n
    ((active_jobs--))
done

echo "✅ All shutdown processes completed"

# Count successful vs failed from status files
failed_services=0
successful_services=0
for ((i=${#compose_files[@]}-1; i>=0; i--)); do
    compose_file="${compose_files[i]}"
    service_name=$(get_service_name "$compose_file")
    status_file="$TEMP_DIR/$service_name.status"
    
    if [ -f "$status_file" ]; then
        status=$(cat "$status_file")
        if [ "$status" = "SUCCESS" ]; then
            ((successful_services++))
        elif [ "$status" = "FAILED" ]; then
            ((failed_services++))
        else
            # Status file exists but contains unexpected value (like "RUNNING")
            ((failed_services++))
        fi
    else
        # Status file doesn't exist, assume failed
        ((failed_services++))
    fi
done

# Additional cleanup: remove orphaned containers
echo ""
echo "🧹 Cleaning up orphaned containers and networks..."
docker container prune -f >/dev/null 2>&1
docker network prune -f >/dev/null 2>&1

# Summary
echo ""
echo "=== Shutdown Summary ==="
echo "Successfully stopped: $successful_services service(s)"
echo "Failed to stop: $failed_services service(s)"
echo "Total processing time: $(date)"

if [ $failed_services -gt 0 ]; then
    echo ""
    echo "⚠️  Some services failed to stop. Check the logs above for details."
    echo "You may need to stop them manually with:"
    echo "  docker ps                    # List running containers"
    echo "  docker stop <container_id>   # Stop specific containers"
    echo "  docker system prune -f       # Clean up system resources"
    exit 1
else
    echo ""
    echo "🏁 All services have been stopped successfully!"
    echo "🎉 Parallel shutdown completed efficiently!"
fi
