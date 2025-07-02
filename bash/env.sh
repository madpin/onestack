#!/bin/bash
# bash/env.sh
# Centralized environment loader and Docker Compose discovery for OneStack
# Usage: source ./bash/env.sh && load_all_env_files

# ===================================================================
# DOCKER COMPOSE DISCOVERY - CENTRALIZED FUNCTIONS
# ===================================================================
# This file centralizes all Docker Compose file discovery logic to
# implement DRY (Don't Repeat Yourself) principles and eliminate
# code duplication across multiple bash scripts.
#
# Key functions:
#   - discover_compose_files(): Main discovery function for all services
#   - find_service_compose_file(): Find a specific service's compose file
#   - get_service_name(): Extract service name from compose file path
#   - print_discovered_files(): Display discovered files with formatting
# ===================================================================

# Loads a single .env file, overwriting existing env vars
load_env_file() {
    local env_file="$1"
    if [ -f "$env_file" ]; then
        echo "Loading environment from: $env_file"
        set -a
        source "$env_file"
        set +a
        return 0
    fi
    return 1
}

# Loads all .env files (root and subdirectories)
load_all_env_files() {
    local env_files_found=0
    # Load root .env file first
    if load_env_file "./.env"; then
        ((env_files_found++))
    fi
    # Find and load all .env files in subdirectories
    while IFS= read -r -d '' env_file; do
        if load_env_file "$env_file"; then
            ((env_files_found++))
        fi
    done < <(find . -name ".env" -not -path "./.env" -print0 2>/dev/null)
    echo "Loaded $env_files_found environment file(s)"
    return 0
}

# Loads environment files for a specific service
# Usage: load_service_env_files "service_name" "compose_file_path"
load_service_env_files() {
    local service_name="$1"
    local compose_file="$2"
    local env_files_found=0
    
    # Always load root .env file first
    if load_env_file "./.env"; then
        ((env_files_found++))
    fi
    
    # Load .env file from the service directory
    local service_dir=$(dirname "$compose_file")
    local service_env_file="$service_dir/.env"
    
    if [ -f "$service_env_file" ]; then
        if load_env_file "$service_env_file"; then
            ((env_files_found++))
        fi
    fi
    
    echo "Loaded $env_files_found environment file(s) for service: $service_name"
    return 0
}

# Discovers Docker Compose files in the workspace
# Usage: discover_compose_files [service_filter] [include_shared]
# Args:
#   service_filter: Optional. Filter results to match this service name
#   include_shared: Optional. Set to "true" to include shared/* directories (default: true)
# Returns: Sets the global array 'compose_files' with discovered files
discover_compose_files() {
    local service_filter="$1"
    local include_shared="${2:-true}"
    
    # Reset the global array
    compose_files=()
    
    # Build find command based on include_shared flag
    local find_results
    if [ "$include_shared" = "true" ]; then
        # Search both root and ./shared/* directories
        find_results=$(find "$(pwd)" \( -path "$(pwd)/shared/*/docker-compose*.yml" -o -path "$(pwd)/shared/*/docker-compose*.yaml" -o -name "docker-compose*.yml" -o -name "docker-compose*.yaml" \) 2>/dev/null)
    else
        # Search only in current directory and subdirectories (excluding shared)
        find_results=$(find "$(pwd)" -name "docker-compose*.yml" -o -name "docker-compose*.yaml" 2>/dev/null)
    fi
    
    # Process the results
    while IFS= read -r compose_file; do
        if [ -n "$compose_file" ] && [ -f "$compose_file" ]; then
            # Convert to relative path from current directory
            local relative_path
            if command -v realpath >/dev/null 2>&1; then
                relative_path=$(realpath --relative-to="$(pwd)" "$compose_file")
            else
                # Fallback if realpath is not available
                relative_path=${compose_file#$(pwd)/}
                relative_path=${relative_path#./}
            fi
            
            # Apply service filter if provided
            if [ -n "$service_filter" ]; then
                local service_dir=$(dirname "$relative_path")
                local service_name=$(basename "$service_dir")
                # Check if service matches (exact match or partial match for shared services)
                if [[ "$service_name" == "$service_filter" || "$service_dir" == *"$service_filter"* ]]; then
                    compose_files+=("$relative_path")
                fi
            else
                compose_files+=("$relative_path")
            fi
        fi
    done <<< "$find_results"
}

# Finds a specific compose file for a service (checks both direct and shared locations)
# Usage: find_service_compose_file "service_name"
# Returns: Sets global variable 'found_compose_file' with the path, or empty if not found
find_service_compose_file() {
    local service_name="$1"
    found_compose_file=""
    
    # Check direct service directory
    if [ -f "./$service_name/docker-compose.yml" ]; then
        found_compose_file="./$service_name/docker-compose.yml"
        return 0
    fi
    
    # Check shared service directory
    if [ -f "./shared/$service_name/docker-compose.yml" ]; then
        found_compose_file="./shared/$service_name/docker-compose.yml"
        return 0
    fi
    
    # Try using the discovery function as fallback
    discover_compose_files "$service_name"
    if [ ${#compose_files[@]} -gt 0 ]; then
        found_compose_file="${compose_files[0]}"
        return 0
    fi
    
    return 1
}

# Prints discovered compose files with optional prefix message
# Usage: print_discovered_files [prefix_message]
print_discovered_files() {
    local prefix_message="$1"
    
    if [ -n "$prefix_message" ]; then
        echo "$prefix_message"
    fi
    
    if [ ${#compose_files[@]} -eq 0 ]; then
        echo "⚠️  No Docker Compose files found!"
        return 1
    fi
    
    echo "Found ${#compose_files[@]} Docker Compose file(s)"
    for compose_file in "${compose_files[@]}"; do
        echo "Found: $compose_file"
    done
    
    return 0
}

# Gets service name from compose file path
# Usage: get_service_name "path/to/docker-compose.yml"
get_service_name() {
    local compose_file="$1"
    local service_dir=$(dirname "$compose_file")
    echo "$(basename "$service_dir")"
}


