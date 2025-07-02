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
echo "Starting services in parallel (max 6 concurrent)..."
failed_services=0
successful_services=0
active_jobs=0

# Temporary directory for status tracking
TEMP_DIR="/tmp/onestack-startup-$$"
mkdir -p "$TEMP_DIR"

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Function to pull/build a single service
pull_build_service() {
    local compose_file="$1"
    local service_name="$2"
    local status_file="$TEMP_DIR/$service_name.pull.status"
    local log_file="$TEMP_DIR/$service_name.pull.log"
    
    if docker compose -f "$compose_file" pull --ignore-buildable > "$log_file" 2>&1 && docker compose -f "$compose_file" build >> "$log_file" 2>&1; then
        echo "SUCCESS" > "$status_file"
        echo "📦 $service_name images ready"
    else
        echo "FAILED" > "$status_file"
        echo "⚠️ $service_name image pull/build had issues (may still work)"
        # Show error details for failed pulls/builds
        echo "   Pull/build details:"
        cat "$log_file" | grep -E "(ERROR|error|Error|failed|Failed|pull|Pull)" | tail -3 | sed 's/^/   /'
    fi
}

# Function to start a single service
start_service_with_logging() {
    local compose_file="$1"
    local service_name="$2"
    local status_file="$TEMP_DIR/$service_name.status"
    
    if docker compose -f "$compose_file" up -d > "$TEMP_DIR/$service_name.log" 2>&1; then
        echo "SUCCESS" > "$status_file"
        echo "✅ $service_name started successfully"
    else
        echo "FAILED" > "$status_file"
        echo "❌ $service_name failed to start"
        # Show error details
        echo "   Error details:"
        cat "$TEMP_DIR/$service_name.log" | tail -5 | sed 's/^/   /'
    fi
}

# Pull and build images first
echo ""
echo "Pulling and building images in parallel (max 6 concurrent)..."
active_jobs=0

for compose_file in "${compose_files[@]}"; do
    service_name=$(get_service_name "$compose_file")
    
    # Wait if we have too many active jobs
    while [ $active_jobs -ge 6 ]; do
        wait -n
        ((active_jobs--))
    done
    
    # Pull/build the service images in background
    pull_build_service "$compose_file" "$service_name" &
    ((active_jobs++))
done

# Wait for all pull/build jobs to complete
while [ $active_jobs -gt 0 ]; do
    wait -n
    ((active_jobs--))
done

echo "📦 All images pulled and built"

# Start services in parallel
echo ""
echo "Starting services in parallel (max 6 concurrent)..."
active_jobs=0
for compose_file in "${compose_files[@]}"; do
    service_name=$(get_service_name "$compose_file")
    
    # Wait if we have too many active jobs
    while [ $active_jobs -ge 6 ]; do
        wait -n
        ((active_jobs--))
    done
    
    # Start the service in background
    start_service_with_logging "$compose_file" "$service_name" &
    ((active_jobs++))
done

# Wait for all jobs to complete
while [ $active_jobs -gt 0 ]; do
    wait -n
    ((active_jobs--))
done

echo "✅ All startup processes completed"

# Count results
for compose_file in "${compose_files[@]}"; do
    service_name=$(get_service_name "$compose_file")
    status_file="$TEMP_DIR/$service_name.status"
    
    if [ -f "$status_file" ]; then
        status=$(cat "$status_file")
        if [ "$status" = "SUCCESS" ]; then
            ((successful_services++))
        else
            ((failed_services++))
        fi
    else
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
