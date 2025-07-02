#!/bin/bash

# Auto Logs Script
# Automatically discovers and shows logs from all Docker Compose services

# Navigate to the project root
cd "$(dirname "$0")/.."

source ./bash/env.sh

# Load all environment variables
load_all_env_files || exit 1

echo "=== OneStack Auto Logs ==="

# Auto-discover Docker Compose files
discover_compose_files

if [ ${#compose_files[@]} -eq 0 ]; then
    echo "No Docker Compose files found!"
    exit 1
fi

echo "Found ${#compose_files[@]} Docker Compose file(s)"

# Parse command line arguments
FOLLOW=""
TAIL_LINES="100"
SERVICE_FILTER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--follow)
            FOLLOW="-f"
            shift
            ;;
        -t|--tail)
            TAIL_LINES="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE_FILTER="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -f, --follow          Follow log output"
            echo "  -t, --tail LINES      Number of lines to show from the end of logs (default: 100)"
            echo "  -s, --service NAME    Show logs for specific service only"
            echo "  -h, --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# If specific service is requested, find it
if [ ! -z "$SERVICE_FILTER" ]; then
    echo "Filtering logs for service: $SERVICE_FILTER"
    found_service=""
    for compose_file in "${compose_files[@]}"; do
        service_name=$(get_service_name "$compose_file")
        if [ "$service_name" = "$SERVICE_FILTER" ]; then
            found_service="$compose_file"
            break
        fi
    done
    
    if [ -z "$found_service" ]; then
        echo "Service '$SERVICE_FILTER' not found!"
        echo "Available services:"
        for compose_file in "${compose_files[@]}"; do
            service_name=$(get_service_name "$compose_file")
            echo "  - $service_name"
        done
        exit 1
    fi
    
    compose_files=("$found_service")
fi

# Show logs from all or filtered services
if [ ${#compose_files[@]} -eq 1 ]; then
    # Single service - show logs directly
    compose_file="${compose_files[0]}"
    service_name=$(get_service_name "$compose_file")
    
    echo "Showing logs for: $service_name"
    echo "Press Ctrl+C to exit"
    echo ""
    
    docker compose -f "$compose_file" logs --tail="$TAIL_LINES" $FOLLOW
else
    # Multiple services - show combined logs with service prefixes
    echo "Showing logs from all services (last $TAIL_LINES lines each)"
    if [ "$FOLLOW" = "-f" ]; then
        echo "Following logs... Press Ctrl+C to exit"
    fi
    echo ""
    
    # Build the docker compose command with all files
    compose_args=()
    for compose_file in "${compose_files[@]}"; do
        compose_args+=("-f" "$compose_file")
    done
    
    # Use docker compose with multiple files
    docker compose "${compose_args[@]}" logs --tail="$TAIL_LINES" $FOLLOW
fi
