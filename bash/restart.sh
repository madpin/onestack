#!/bin/bash
# bash/restart.sh
# Restarts all docker-compose services, or a specific one if given as argument

cd "$(dirname "$0")/.."
source ./bash/env.sh

SERVICE="$1"

if [ -n "$SERVICE" ]; then
    # Use centralized service discovery (load_service_env_files will handle env loading)
    if find_service_compose_file "$SERVICE"; then
        echo "Restarting docker-compose in $SERVICE ($found_compose_file)..."
        # Load environment before down command
        load_service_env_files "$SERVICE" "$found_compose_file"
        docker compose -f "$found_compose_file" down
        docker compose -f "$found_compose_file" up -d
        exit $?
    fi
    
    # If not found, try to restart a running container/service with that name
    CONTAINER_ID=$(docker ps -q -f name="^${SERVICE}$")
    if [ -n "$CONTAINER_ID" ]; then
        echo "Restarting container $SERVICE..."
        docker restart $SERVICE
        exit $?
    else
        echo "No docker-compose.yml found for service '$SERVICE' and no running container named '$SERVICE' found."
        exit 1
    fi
else
    # Load all environment files when restarting all services
    load_all_env_files || exit 1
    
    # Dynamically find and restart all docker-compose.yml files in subdirectories, including shared/*
    discover_compose_files
    for compose_file in "${compose_files[@]}"; do
        service_name=$(get_service_name "$compose_file")
        echo "Restarting docker-compose in $service_name ($compose_file)..."
        docker compose -f "$compose_file" down
    done
    
    # Reload environment before starting services
    load_all_env_files || exit 1
    for compose_file in "${compose_files[@]}"; do
        service_name=$(get_service_name "$compose_file")
        echo "Starting docker-compose in $service_name ($compose_file)..."
        docker compose -f "$compose_file" up -d
    done
fi
