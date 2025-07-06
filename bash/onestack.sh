#!/bin/bash
# bash/onestack.sh
# Centralized script for OneStack Docker management.
# Handles actions like up, down, logs, status, clean, network, restart.
# Meant to be called by Makefile targets or directly for advanced usage.

# Ensure the script operates from the project root directory.
cd "$(dirname "$0")/.." || exit 1

# ===================================================================
# GLOBAL VARIABLES & CONFIGURATION
# ===================================================================
MAX_PARALLEL_JOBS=10 # Max concurrent Docker operations for up/down actions.
SHUTDOWN_TIMEOUT=60  # Timeout in seconds for each service shutdown during 'down' action.

# Array to hold discovered docker-compose files relevant to the current action.
compose_files=()
# Variable to hold a single found compose file
found_compose_file=""

# ===================================================================
# CORE HELPER FUNCTIONS
# These functions provide foundational capabilities for discovering services,
# loading environment variables, and other utilities.
# Originally migrated and adapted from the old bash/env.sh.
# ===================================================================

# Loads a single .env file into the current environment.
# Variables in the file can overwrite existing environment variables.
# Usage: load_env_file "/path/to/.env"
load_env_file() {
    local env_file="$1"
    if [ -f "$env_file" ]; then
        echo "Loading environment from: $env_file"
        set -a
        # shellcheck source=/dev/null
        source "$env_file"
        set +a
        return 0
    fi
    return 1
}

# Loads all .env files (root and subdirectories)
# Used when no specific service is targeted.
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

# Loads environment files for a specific service context
# Always loads root .env, then service's .env
load_service_env_files() {
    local service_name="$1"
    local compose_file_path="$2"
    local env_files_loaded_count=0

    echo "Loading .env files for service '$service_name'"

    # Load root .env file first (if it exists)
    if [ -f "./.env" ]; then
        if load_env_file "./.env"; then
            ((env_files_loaded_count++))
        fi
    fi

    # Determine service directory and load its .env file (if it exists)
    local service_dir
    service_dir=$(dirname "$compose_file_path")
    local service_env_file="$service_dir/.env"

    if [ -f "$service_env_file" ]; then
        # Avoid double-loading if service_dir is root
        if [ "$service_env_file" != "./.env" ]; then
            if load_env_file "$service_env_file"; then
                ((env_files_loaded_count++))
            fi
        fi
    fi
    echo "Total $env_files_loaded_count .env file(s) processed for $service_name."
}


# Discovers Docker Compose files in the workspace
# Usage: discover_compose_files [service_filter]
# Args:
#   service_filter: Optional. Filter results to match this service name or directory.
#                   If filter is "all", discovers all services.
# Sets the global array 'compose_files'
discover_compose_files() {
    local service_filter="$1"
    compose_files=() # Reset the global array

    local find_paths_args=()
    # Common find arguments for docker-compose files
    local find_common_args=(-name "docker-compose.yml" -o -name "docker-compose.yaml" -o -name "docker-compose.*.yml" -o -name "docker-compose.*.yaml")

    if [ -z "$service_filter" ] || [ "$service_filter" == "all" ]; then
        # Find all docker-compose files in the current directory and subdirectories
        # Exclude .git, .github, and other common non-service directories if necessary
        find_paths_args+=(-path "./*/*docker-compose*.yml" -o -path "./*/*docker-compose*.yaml")
        # This will find files like ./traefik/docker-compose.yml, ./shared/postgres/docker-compose.yml
    else
        # Filter by service name or path
        # This allows for patterns like "traefik" or "shared/postgres"
        # Search for compose files within a directory matching the filter, or a file directly matching
        find_paths_args+=(-path "./$service_filter/docker-compose*.yml" -o -path "./$service_filter/docker-compose*.yaml")
        find_paths_args+=(-o -path "./shared/$service_filter/docker-compose*.yml" -o -path "./shared/$service_filter/docker-compose*.yaml")
        # Also, if the service_filter is a direct path to a compose file
        if [[ "$service_filter" == *docker-compose*.yml || "$service_filter" == *docker-compose*.yaml ]] && [ -f "$service_filter" ]; then
             compose_files+=("$service_filter")
             return 0 # Early exit if a direct file path is provided and valid
        fi
    fi

    # Execute find command
    # Using -print0 and read -d $'\0' for safe handling of filenames with spaces/newlines
    local current_dir
    current_dir=$(pwd)
    while IFS= read -r -d $'\0' compose_file; do
        # Ensure the file path is relative to the project root
        local relative_path="${compose_file#"$current_dir"/}"
        relative_path="${relative_path#./}" # Ensure it doesn't start with ./ if already relative

        # Avoid duplicates
        if [[ ! " ${compose_files[*]} " =~ " ${relative_path} " ]]; then
            compose_files+=("$relative_path")
        fi
    done < <(find . \( "${find_paths_args[@]}" \) -print0 2>/dev/null | sort -uz)


    if [ ${#compose_files[@]} -eq 0 ] && [ -n "$service_filter" ] && [ "$service_filter" != "all" ]; then
        # If a specific service was requested but not found, try a broader search for that name
        # This handles cases where the service_filter is just "traefik" and the file is "traefik/docker-compose.yml"
        local fallback_find_results
        fallback_find_results=$(find . \( -path "*/$service_filter/docker-compose*.yml" -o -path "*/$service_filter/docker-compose*.yaml" \) -print0 2>/dev/null | sort -uz)
         while IFS= read -r -d $'\0' compose_file; do
            local relative_path="${compose_file#"$current_dir"/}"
            relative_path="${relative_path#./}"
            if [[ ! " ${compose_files[*]} " =~ " ${relative_path} " ]]; then
                compose_files+=("$relative_path")
            fi
        done < <(echo -n "$fallback_find_results")
    fi
}


# Finds a specific compose file for a service
# Usage: find_service_compose_file "service_name"
# Returns: Sets global variable 'found_compose_file' with the path, or empty if not found
# This is useful when an operation targets a single, explicitly named service.
find_service_compose_file() {
    local service_name="$1"
    found_compose_file="" # Reset

    # Attempt to find using discover_compose_files with the specific service name as filter
    discover_compose_files "$service_name"

    if [ ${#compose_files[@]} -gt 0 ]; then
        # If multiple matches (e.g. service_name is part of a path), prioritize direct matches
        for f in "${compose_files[@]}"; do
            if [[ "$(get_service_name "$f")" == "$service_name" ]]; then
                found_compose_file="$f"
                # Update compose_files to only contain this one for clarity if needed for subsequent ops
                compose_files=("$f")
                return 0
            fi
        done
        # If no exact dirname match, take the first one found (could be a path like "shared/service_name")
        found_compose_file="${compose_files[0]}"
        return 0
    fi
    return 1 # Not found
}

# Prints discovered compose files with optional prefix message
# Usage: print_discovered_files [prefix_message]
print_discovered_files() {
    local prefix_message="$1"

    if [ -n "$prefix_message" ]; then
        echo "$prefix_message"
    fi

    if [ ${#compose_files[@]} -eq 0 ]; then
        echo "⚠️ No Docker Compose files found matching the criteria."
        return 1
    fi

    echo "Found ${#compose_files[@]} Docker Compose file(s):"
    for file_path in "${compose_files[@]}"; do
        echo "  - $file_path"
    done
    return 0
}

# Gets service name from compose file path (typically the directory name)
# Usage: get_service_name "path/to/docker-compose.yml"
get_service_name() {
    local compose_file_path="$1"
    # Robustly get the directory of the compose file, then its basename
    local service_dir
    service_dir=$(dirname "$compose_file_path")
    echo "$(basename "$service_dir")"
}

# ===================================================================
# ACTION FUNCTIONS
# Each function below corresponds to a management action (e.g., up, down, logs).
# They are called by the main() function based on the first script argument.
# ===================================================================

# Starts services.
# - Handles network creation via action_network.
# - Discovers specified (or all) services.
# - Pulls/builds images in parallel.
# - Starts services in parallel.
# - Loads .env files (global then service-specific).
# Usage: action_up [service_filter]
action_up() {
    local service_filter="$1"
    echo "=== OneStack Auto Startup: ${service_filter:-all services} ==="

    # Ensure networks exist (defer to network action or ensure it's called)
    echo ""
    echo "Ensuring networks are created..."
    # Assuming action_network handles its own .env loading or global is sufficient
    action_network # This might need to be more selective or handled differently
    if [ $? -ne 0 ]; then
        echo "✗ Network setup failed"
        # exit 1 # Decide if up should fail completely if network fails
    fi

    # Load all .env files if no specific service, otherwise service-specific will be handled per service
    if [ -z "$service_filter" ]; then
        load_all_env_files || exit 1
    fi

    echo ""
    discover_compose_files "$service_filter"
    if ! print_discovered_files "Discovering Docker Compose files for UP action..."; then
        echo "✗ No Docker Compose files found for: ${service_filter:-all services}"
        return 1
    fi

    local temp_dir
    temp_dir="/tmp/onestack-startup-$$"
    mkdir -p "$temp_dir"
    trap 'rm -rf "$temp_dir"' EXIT

    # Function to pull/build a single service
    _pull_build_service_up() {
        local compose_file="$1"
        local service_name="$2" # Extracted from compose_file path
        local status_file="$temp_dir/$service_name.pull.status"
        local log_file="$temp_dir/$service_name.pull.log"

        # Specific env loading for this service before pull/build
        load_service_env_files "$service_name" "$compose_file"

        echo "RUNNING" > "$status_file"
        echo "Pulling/Building for $service_name (file: $compose_file)..."
        # Run docker compose commands with project directory set to service's directory
        local service_project_dir
        service_project_dir=$(dirname "$compose_file")
        if docker compose -f "$compose_file" -p "${service_name}" pull --ignore-buildable > "$log_file" 2>&1 && \
           docker compose -f "$compose_file" -p "${service_name}" build --quiet >> "$log_file" 2>&1; then
            echo "SUCCESS" > "$status_file"
            echo "📦 $service_name images ready"
        else
            echo "FAILED" > "$status_file"
            echo "⚠️ $service_name image pull/build had issues (may still work)"
            echo "   Pull/build details for $service_name (see $log_file):"
            grep -E "(ERROR|error|Error|failed|Failed|pull|Pull|not found)" "$log_file" | tail -5 | sed 's/^/   /'
        fi
    }

    # Function to start a single service
    _start_service_with_logging_up() {
        local compose_file="$1"
        local service_name="$2" # Extracted from compose_file path
        local status_file="$temp_dir/$service_name.status"
        local log_file="$temp_dir/$service_name.log"

        # Specific env loading for this service before up
        # load_service_env_files "$service_name" "$compose_file" # Already done in pull/build, ensure it's effective

        echo "RUNNING" > "$status_file"
        echo "Starting $service_name (file: $compose_file)..."
        # Run docker compose commands with project directory set to service's directory
        local service_project_dir
        service_project_dir=$(dirname "$compose_file")

        # Use -p (project name) to ensure containers are uniquely named, especially if multiple compose files define same service names
        # Project name derived from service name to ensure uniqueness
        if docker compose -f "$compose_file" -p "${service_name}" up -d > "$log_file" 2>&1; then
            echo "SUCCESS" > "$status_file"
            echo "✅ $service_name started successfully"
        else
            echo "FAILED" > "$status_file"
            echo "❌ $service_name failed to start"
            echo "   Error details for $service_name (see $log_file):"
            tail -5 "$log_file" | sed 's/^/   /'
        fi
    }

    echo ""
    echo "Pulling and building images in parallel (max $MAX_PARALLEL_JOBS concurrent)..."
    local active_jobs=0
    for file_path in "${compose_files[@]}"; do
        local current_service_name
        current_service_name=$(get_service_name "$file_path")

        while [ $active_jobs -ge $MAX_PARALLEL_JOBS ]; do
            wait -n
            ((active_jobs--))
        done

        _pull_build_service_up "$file_path" "$current_service_name" &
        ((active_jobs++))
    done
    while [ $active_jobs -gt 0 ]; do wait -n; ((active_jobs--)); done
    echo "📦 All image pull/build processes completed."

    echo ""
    echo "Starting services in parallel (max $MAX_PARALLEL_JOBS concurrent)..."
    active_jobs=0
    local successful_services=0
    local failed_services=0

    for file_path in "${compose_files[@]}"; do
        local current_service_name
        current_service_name=$(get_service_name "$file_path")

        while [ $active_jobs -ge $MAX_PARALLEL_JOBS ]; do
            wait -n
            ((active_jobs--))
        done

        _start_service_with_logging_up "$file_path" "$current_service_name" &
        ((active_jobs++))
    done
    while [ $active_jobs -gt 0 ]; do wait -n; ((active_jobs--)); done
    echo "✅ All startup processes initiated."

    # Count results
    for file_path in "${compose_files[@]}"; do
        local current_service_name
        current_service_name=$(get_service_name "$file_path")
        local status_file="$temp_dir/$current_service_name.status"

        if [ -f "$status_file" ]; then
            local status
            status=$(cat "$status_file" 2>/dev/null || echo "FAILED")
            if [ "$status" = "SUCCESS" ]; then
                ((successful_services++))
            else # FAILED or RUNNING (if script interrupted)
                ((failed_services++))
            fi
        else # Status file doesn't exist, assume failed
            ((failed_services++))
        fi
    done

    echo ""
    echo "=== Startup Summary ==="
    echo "Successfully started: $successful_services service(s)"
    echo "Failed to start: $failed_services service(s)"

    if [ $failed_services -gt 0 ]; then
        echo ""
        echo "⚠️ Some services failed to start. Check the logs above for details."
        return 1 # Indicate failure
    else
        echo ""
        echo "🎉 All specified services are up and running!"
    fi
    return 0
}

}

action_logs() {
    echo "[onestack.sh] Performing LOGS action..."
    # $1 = service_name (optional), subsequent args are for docker logs

    local service_target # Can be a service name or "all"
    local service_name_for_logs # Specific service name if provided
    local follow_logs=""
    local tail_lines="100" # Default tail lines
    local additional_opts=() # Store other docker compose logs options

    # Simple arg parsing for logs
    # logs [service_name] [-f] [-t N] [other_docker_opts]
    # logs [-f] [-t N] [other_docker_opts] (implies all services)

    # Check if first arg is a known action or option, if not, assume it's a service name
    if [[ -n "$1" && "$1" != "-f" && "$1" != "--follow" && "$1" != "-t" && "$1" != "--tail" ]]; then
        service_target="$1"
        service_name_for_logs="$1"
        shift # Consume service name
    else
        service_target="all" # Default to all services if no name is given first
    fi

    # Parse options like -f, -t
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--follow)
                follow_logs="-f"
                shift
                ;;
            -t|--tail)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    tail_lines="$2"
                    shift 2
                elif [[ "$1" == *"="* ]]; then # handles --tail=N
                    tail_lines="${1#*=}"
                    shift
                else
                    echo "Error: --tail requires a number." >&2
                    return 1
                fi
                ;;
            *) # Any other options are passed directly to docker compose logs
                additional_opts+=("$1")
                shift
                ;;
        esac
    done

    echo "Log parameters: Service Target: '${service_target}', Follow: '${follow_logs:-off}', Tail: '${tail_lines}', Additional Opts: '${additional_opts[*]}'"


    if [ "$service_target" == "all" ]; then
        echo "Loading all .env files for combined logs..."
        load_all_env_files # Load all for combined view, individual services might have specifics but this is for general view

        discover_compose_files "all"
        if ! print_discovered_files "Showing combined logs for all services:"; then
            return 1
        fi

        if [ ${#compose_files[@]} -eq 0 ]; then
            echo "No services found to show logs for."
            return 1
        fi

        local compose_cmd_args=()
        for f in "${compose_files[@]}"; do
            # For combined logs, we need to use the -p for each to avoid conflicts if service names are the same across files
            # However, 'docker compose logs' with multiple -f flags handles this by prefixing.
            # We just need to ensure each service's .env is loaded if its specific config affects logging (rare).
            # The global load_all_env_files should generally suffice here.
            compose_cmd_args+=("-f" "$f")
        done

        echo "Showing combined logs (tail: $tail_lines${follow_logs:+, follow mode}). Press Ctrl+C to exit."
        # shellcheck disable=SC2086 # $follow_logs should not be quoted if empty
        docker compose ${compose_cmd_args[@]} logs --tail="$tail_lines" $follow_logs "${additional_opts[@]}"

    else
        # Specific service target
        find_service_compose_file "$service_name_for_logs"
        if [ -z "$found_compose_file" ]; then
            echo "Service '$service_name_for_logs' not found."
            # Try to list available services
            discover_compose_files "all"
            echo "Available services (based on directory names):"
            for cf in "${compose_files[@]}"; do
                echo "  - $(get_service_name "$cf")"
            done
            return 1
        fi

        local service_actual_name
        service_actual_name=$(get_service_name "$found_compose_file")
        load_service_env_files "$service_actual_name" "$found_compose_file"

        echo "Showing logs for service: $service_actual_name (file: $found_compose_file, tail: $tail_lines${follow_logs:+, follow mode}). Press Ctrl+C to exit."
        # Use -p project name to ensure logs are for the correct instance if names are reused
        # shellcheck disable=SC2086
        docker compose -f "$found_compose_file" -p "$service_actual_name" logs --tail="$tail_lines" $follow_logs "${additional_opts[@]}"
    fi
    return 0
}


action_status() {

action_down() {
    local service_filter="$1"
    echo "=== OneStack Auto Shutdown: ${service_filter:-all services} ==="

    # Load all .env files if no specific service, otherwise service-specific will be handled per service
    if [ -z "$service_filter" ]; then
        load_all_env_files || exit 1 # Essential for proper shutdown variables
    fi

    echo ""
    discover_compose_files "$service_filter"
    if ! print_discovered_files "Discovering Docker Compose files for DOWN action..."; then
        echo "Nothing to stop for: ${service_filter:-all services}"
        return 0 # Not an error if nothing found to stop
    fi

    local temp_dir
    temp_dir="/tmp/onestack-shutdown-$$"
    mkdir -p "$temp_dir"
    trap 'rm -rf "$temp_dir"' EXIT

    _stop_service_with_logging_down() {
        local compose_file="$1"
        local service_name="$2" # Extracted from compose_file path
        local log_file="$temp_dir/$service_name.down.log"
        local status_file="$temp_dir/$service_name.down.status"

        # Specific env loading for this service before down
        load_service_env_files "$service_name" "$compose_file"

        echo "RUNNING" > "$status_file"
        echo "Stopping $service_name (file: $compose_file)..."
        # Use -p (project name) matching the one used in 'up'
        if timeout "$SHUTDOWN_TIMEOUT" docker compose -f "$compose_file" -p "${service_name}" down > "$log_file" 2>&1; then
            echo "SUCCESS" > "$status_file"
            echo "✅ $service_name stopped successfully"
        else
            local exit_code=$?
            echo "FAILED" > "$status_file"
            if [ $exit_code -eq 124 ]; then # Timeout specific exit code
                echo "❌ $service_name failed to stop (timeout after ${SHUTDOWN_TIMEOUT}s)"
            else
                echo "❌ $service_name failed to stop (error)"
            fi
            echo "   Error details for $service_name (see $log_file):"
            cat "$log_file" | sed 's/^/   /'
        fi
    }

    echo ""
    echo "Stopping services in parallel (max $MAX_PARALLEL_JOBS concurrent, ${SHUTDOWN_TIMEOUT}s timeout)..."
    local active_jobs=0
    local successful_services=0
    local failed_services=0

    # Process services in reverse order of discovery (helps with dependencies if any)
    for ((i=${#compose_files[@]}-1; i>=0; i--)); do
        local file_path="${compose_files[i]}"
        local current_service_name
        current_service_name=$(get_service_name "$file_path")

        while [ $active_jobs -ge $MAX_PARALLEL_JOBS ]; do
            wait -n
            ((active_jobs--))
        done

        _stop_service_with_logging_down "$file_path" "$current_service_name" &
        ((active_jobs++))
    done
    while [ $active_jobs -gt 0 ]; do wait -n; ((active_jobs--)); done
    echo "✅ All shutdown processes initiated."

    # Count results
    for ((i=${#compose_files[@]}-1; i>=0; i--)); do
        local file_path="${compose_files[i]}"
        local current_service_name
        current_service_name=$(get_service_name "$file_path")
        local status_file="$temp_dir/$current_service_name.down.status"

        if [ -f "$status_file" ]; then
            local status
            status=$(cat "$status_file" 2>/dev/null || echo "FAILED")
            if [ "$status" = "SUCCESS" ]; then
                ((successful_services++))
            else
                ((failed_services++))
            fi
        else
            ((failed_services++))
        fi
    done

    # Optional: Add pruning of orphaned containers/networks if 'clean' isn't used or if desired here
    # echo ""
    # echo "🧹 Cleaning up orphaned containers and networks..."
    # docker container prune -f >/dev/null 2>&1
    # docker network prune -f >/dev/null 2>&1

    echo ""
    echo "=== Shutdown Summary ==="
    echo "Successfully stopped: $successful_services service(s)"
    echo "Failed to stop: $failed_services service(s)"

    if [ $failed_services -gt 0 ]; then
        echo ""
        echo "⚠️ Some services failed to stop. Check the logs above for details."
        echo "You may need to stop them manually (e.g. docker stop <container_id> or docker compose -f ... down)"
        return 1 # Indicate failure
    else
        echo ""
        echo "🏁 All specified services have been stopped successfully!"
    fi
    return 0
}

action_logs() {
    echo "[onestack.sh] Performing LOGS action for: ${1}"
    # Logic from bash/logs.sh will go here
    # $1 would be service name, $2... would be log options
    shift # Remove 'logs' action command
    local service_name_arg="$1"
    shift # Remove service name for options
    local log_opts="$@"

    find_service_compose_file "$service_name_arg"
    if [ -z "$found_compose_file" ]; then
        echo "Service $service_name_arg not found."
        return 1
    fi
    load_service_env_files "$service_name_arg" "$found_compose_file"
    echo "Showing logs for $service_name_arg (file: $found_compose_file) with options: $log_opts"
    # ... actual docker compose logs logic ...
}

action_status() {
    echo "[onestack.sh] Performing STATUS action"

    # Color codes
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local BLUE='\033[1;34m'
    local CYAN='\033[1;36m'
    local NC='\033[0m' # No Color

    printf "${CYAN}=== OneStack Service Status ===${NC}\n"
    # Simplified legend for now, can be enhanced
    printf "${BLUE}Status based on 'docker compose ps' output.${NC}\n\n"

    # Discover all compose files. Status should generally reflect everything.
    # Pass "all" to discover_compose_files to get all services.
    # The original script had "false" for include_shared, but status should ideally show all.
    # Let's assume "all" is the desired behavior for a comprehensive status.
    discover_compose_files "all"

    if [ ${#compose_files[@]} -eq 0 ]; then
        printf "${RED}No Docker Compose files found to check status!${NC}\n"
        return 1
    fi

    print_discovered_files "Checking status for the following services/configurations:"

    local overall_issue_found=0

    for file_path in "${compose_files[@]}"; do
        local service_name_from_path
        service_name_from_path=$(get_service_name "$file_path")

        # Load .env specific to this service context for 'docker compose ps'
        load_service_env_files "$service_name_from_path" "$file_path"

        printf "\n${YELLOW}==============================${NC}\n"
        printf "${GREEN}Service Config: $service_name_from_path${NC} (${CYAN}$file_path${NC})\n"
        printf "${BLUE}--------------------------------${NC}\n"

        # Get status output, using the service name as project name for consistency
        # Using --all to show stopped containers as well.
        local status_output
        status_output=$(docker compose -f "$file_path" -p "$service_name_from_path" ps --all --format "table {{.Name}}\t{{.State}}\t{{.Status}}\t{{.Health}}")

        if [ -z "$status_output" ]; then
            printf "${YELLOW}No services defined or running for this configuration.${NC}\n"
            continue
        fi

        local header_processed=0
        while IFS= read -r line; do
            if [ $header_processed -eq 0 ]; then
                printf "%s\n" "$line" # Print header as is
                header_processed=1
                continue
            fi

            # Default color
            local line_color="$NC"
            if [[ "$line" == *"unhealthy"* || "$line" == *"restarting"* ]]; then
                line_color="$RED"
                overall_issue_found=1
            elif [[ "$line" == *"running"* || "$line" == *"Up"* ]]; then # "Up" is part of "Status"
                 # Check Health part if available
                if [[ "$line" == *"starting"* ]]; then
                    line_color="$YELLOW" # Yellow for starting
                elif [[ "$line" == *"(healthy)"* ]]; then
                    line_color="$GREEN"
                elif [[ "$line" == *"(unhealthy)"* ]]; then # Health check explicitly unhealthy
                    line_color="$RED"
                    overall_issue_found=1
                else # No health check or health is empty, but running
                    line_color="$GREEN"
                fi
            elif [[ "$line" == *"exited"* || "$line" == *"stopped"* || "$line" == *"created"* ]]; then
                line_color="$YELLOW" # Yellow for non-running states that aren't errors
            elif [[ "$line" == *"error"* || "$line" == *"dead"* ]]; then
                line_color="$RED"
                overall_issue_found=1
            fi
            printf "${line_color}%s${NC}\n" "$line"
        done <<< "$status_output"
    done

    printf "\n${CYAN}=== End of Status ===${NC}\n"
    if [ $overall_issue_found -ne 0 ]; then
        printf "${RED}Some services are unhealthy or not running as expected. Please review the status above.${NC}\n"
        return 1 # Indicate that there might be issues
    fi
    return 0
}

action_restart() {
    local service_filter="$1" # Optional: specific service/group to restart
    echo "=== OneStack Service Restart: ${service_filter:-all services} ==="

    # The restart action will effectively call 'down' then 'up'
    # for the specified services or all services.
    # Environment loading and service discovery are handled by action_down and action_up.

    echo ""
    echo "Step 1: Stopping services..."
    action_down "$service_filter"
    local down_status=$? # Capture exit status of down action

    if [ $down_status -ne 0 ]; then
        echo "⚠️ Services failed to stop cleanly. Proceeding with startup, but there might be issues."
        # Depending on desired strictness, could exit here:
        # echo "❌ Aborting restart due to shutdown failures."
        # return 1
    else
        echo "✅ Services stopped successfully."
    fi

    echo ""
    echo "Step 2: Starting services..."
    action_up "$service_filter"
    local up_status=$? # Capture exit status of up action

    if [ $up_status -ne 0 ]; then
        echo "❌ Some services failed to start during restart."
        return 1
    else
        echo "🎉 Services restarted successfully!"
    fi

    return 0
}

action_network() {
    echo "=== OneStack Network Management ==="

    # Load all environment variables first to ensure all network names are available.
    # This is crucial as network names can be defined in the root .env or service-specific .env files,
    # and action_up calls action_network before individual service .env files might be loaded by action_up's loop.
    load_all_env_files || return 1

    local networks_processed_count=0
    local networks_created_count=0
    local networks_failed_count=0

    # Internal function to create a single network
    _create_single_network() {
        local network_name="$1"
        if [ -z "$network_name" ]; then
            echo "Warning: Network name is empty, skipping creation."
            return 1 # Indicate skip/fail for this attempt
        fi

        # Check if network already exists
        if docker network inspect "$network_name" >/dev/null 2>&1; then
            echo "✓ Network '$network_name' already exists."
            return 0 # Success, already exists
        else
            echo "Creating network: $network_name"
            if docker network create "$network_name" >/dev/null; then # Suppress verbose output from docker
                echo "✓ Network '$network_name' created successfully."
                ((networks_created_count++))
                return 0 # Success, created
            else
                echo "✗ Failed to create network '$network_name'."
                ((networks_failed_count++))
                return 1 # Failure to create
            fi
        fi
    }

    # Gather all unique network names from relevant environment variables
    # Common ones: WEB_NETWORK_NAME, TRAEFIK_NETWORK_NAME, etc.
    # Also, any variable ending with _NETWORK or _NETWORK_NAME
    local potential_network_vars
    potential_network_vars=$(env | grep -E 'NETWORK(_NAME)?=' | cut -d= -f1)

    local declared_networks=()
    if [ -n "$WEB_NETWORK_NAME" ]; then
        declared_networks+=("$WEB_NETWORK_NAME")
    fi

    for var_name in $potential_network_vars; do
        local network_value="${!var_name}" # Indirect expansion
        if [ -n "$network_value" ]; then
            # Add to list if not already present
            if [[ ! " ${declared_networks[*]} " =~ " ${network_value} " ]]; then
                 declared_networks+=("$network_value")
            fi
        fi
    done

    if [ ${#declared_networks[@]} -eq 0 ]; then
        echo "No network names found in environment variables (e.g., WEB_NETWORK_NAME)."
        # This might not be an error if no services require specific networks yet
        # For now, let's just inform and proceed.
    else
        echo "Found the following network names to ensure existence: ${declared_networks[*]}"
    fi

    for net_name in "${declared_networks[@]}"; do
        _create_single_network "$net_name"
        ((networks_processed_count++))
    done

    echo ""
    echo "=== Network Setup Summary ==="
    echo "Networks processed: $networks_processed_count"
    echo "Networks newly created: $networks_created_count"
    echo "Networks failed to create: $networks_failed_count"

    if [ $networks_failed_count -gt 0 ]; then
        echo "⚠️ Some networks failed to create. This might cause issues for services."
        return 1 # Indicate failure
    elif [ ${#declared_networks[@]} -eq 0 ] && [ $networks_created_count -eq 0 ]; then
        echo "No specific networks were defined or created. Services will use default Docker networks if not specified in compose files."
        # This is not necessarily an error, could be by design for simple setups.
        # For now, return success. If strict network policy is needed, this could be an error.
        return 0
    fi

    echo "Network setup completed."
    return 0
}

action_clean() {
    echo "=== OneStack Auto Cleanup ==="
    local extra_args="$@" # Capture any extra args like --all-volumes or --remove-images

    # Step 1: Stop all services
    echo ""
    echo "Step 1: Stopping all services..."
    action_down "all" # "all" ensures it tries to stop everything defined
    if [ $? -ne 0 ]; then
        echo "⚠️ Warning: Some services may not have stopped properly. Continuing cleanup."
    else
        echo "✅ All services stopped."
    fi

    # Step 2: Clean up defined networks
    # Networks should be removed after services are down.
    # load_all_env_files is called by action_network if needed, or here explicitly
    echo ""
    echo "Step 2: Cleaning up defined networks..."
    load_all_env_files || return 1 # Needed to identify network names from .env

    local networks_removed_count=0
    local potential_network_vars
    potential_network_vars=$(env | grep -E 'NETWORK(_NAME)?=' | cut -d= -f1)
    local declared_networks_to_remove=()

    if [ -n "$WEB_NETWORK_NAME" ]; then
        declared_networks_to_remove+=("$WEB_NETWORK_NAME")
    fi
    for var_name in $potential_network_vars; do
        local network_value="${!var_name}"
        if [ -n "$network_value" ]; then
            if [[ ! " ${declared_networks_to_remove[*]} " =~ " ${network_value} " ]]; then
                 declared_networks_to_remove+=("$network_value")
            fi
        fi
    done

    if [ ${#declared_networks_to_remove[@]} -gt 0 ]; then
        echo "Attempting to remove the following defined networks: ${declared_networks_to_remove[*]}"
        for net_name in "${declared_networks_to_remove[@]}"; do
            if docker network inspect "$net_name" >/dev/null 2>&1; then
                echo "Removing network: $net_name"
                if docker network rm "$net_name" >/dev/null 2>&1; then
                    echo "✓ Network '$net_name' removed."
                    ((networks_removed_count++))
                else
                    echo "⚠️ Could not remove network '$net_name' (may still be in use by other containers not part of this stack, or removal failed)."
                fi
            else
                echo "Network '$net_name' not found (already removed or never created)."
            fi
        done
    else
        echo "No specific networks (like WEB_NETWORK_NAME) found defined in .env files to target for removal."
    fi

    # Step 3: Clean up general unused Docker resources
    echo ""
    echo "Step 3: Cleaning up general unused Docker resources..."

    echo "Removing stopped containers..."
    docker container prune -f

    # By default, prune only anonymous volumes.
    # Add a flag e.g. `make clean ARGS=--all-volumes` or `onestack.sh clean --all-volumes` to prune all unused volumes.
    if [[ " ${extra_args[*]} " =~ " --all-volumes " ]]; then
        echo "Removing all unused volumes (including named ones not attached to any container)..."
        echo "WARNING: This will remove ALL unused volumes. Ensure no important data is in unattached named volumes."
        read -p "Proceed with removing all unused volumes? (yes/NO): " -r confirmation
        if [[ "$confirmation" == "yes" ]]; then
            docker volume prune -f
            echo "All unused volumes pruned."
        else
            echo "Skipping pruning of all unused volumes."
            echo "Pruning only anonymous unused volumes..."
            docker volume ls -qf dangling=true | xargs -r docker volume rm
        fi
    else
        echo "Removing unused anonymous volumes (use 'clean --all-volumes' to include named)..."
        docker volume ls -qf dangling=true | xargs -r docker volume rm # More targeted anonymous volume removal
    fi

    echo "Removing unused networks (Docker's general prune)..."
    docker network prune -f

    # Optional: Image pruning
    # Add a flag e.g. `make clean ARGS=--remove-images` or `onestack.sh clean --remove-images`
    if [[ " ${extra_args[*]} " =~ " --remove-images " ]]; then
        echo "Removing unused images (dangling and unreferenced)..."
        docker image prune -a -f # -a prunes all unused images, not just dangling
    elif [[ " ${extra_args[*]} " =~ " --remove-dangling-images " ]]; then
        echo "Removing dangling images..."
        docker image prune -f
    else
        echo "Skipping image pruning. Use 'clean --remove-dangling-images' or 'clean --remove-images' for image cleanup."
    fi

    echo ""
    echo "=== Cleanup Summary ==="
    echo "Defined networks targeted for removal: ${#declared_networks_to_remove[@]}"
    echo "Defined networks actually removed: $networks_removed_count"
    echo "Docker resource pruning completed (containers, anonymous volumes, networks)."
    echo ""
    echo "🧹 Cleanup process finished!"
    echo "Note: For more aggressive system-wide cleanup, consider 'docker system prune -a --volumes' (⚠️ highly destructive)."
    return 0
}


# ===================================================================
# MAIN COMMAND PARSING AND EXECUTION
# This section determines which action function to call based on script arguments.
# ===================================================================

# Main function to parse the command and call the appropriate action_ function.
# Usage: ./onestack.sh <action> [service_filter_or_args...]
main() {
    # Ensure script is not sourced, but executed
    if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
        # Script is being executed
        : # Proceed
    else
        # Script is being sourced, functions are now available.
        # Return to prevent main() logic from running in sourced context.
        return 0
    fi

    local action="$1"
    shift # Remove the action from arguments list, remaining are params for the action

    case "$action" in
        up)
            action_up "$@"
            ;;
        down)
            action_down "$@"
            ;;
        logs)
            action_logs "$@"
            ;;
        status)
            action_status "$@"
            ;;
        restart)
            action_restart "$@"
            ;;
        network)
            action_network "$@"
            ;;
        clean)
            action_clean "$@"
            ;;
        # Internal/utility functions that could be called directly for testing/dev
        _discover) # Example: bash bash/onestack.sh _discover traefik
            discover_compose_files "$1"
            print_discovered_files "Discovery results:"
            ;;
        _load_envs) # Example: bash bash/onestack.sh _load_envs traefik traefik/docker-compose.yml
            load_service_env_files "$1" "$2"
            ;;
        *)
            echo "Usage: $0 {up|down|logs|status|restart|network|clean} [service_name/filter] [options...]"
            echo "Internal utilities:"
            echo "  $0 _discover [service_filter]"
            echo "  $0 _load_envs <service_name> <compose_file_path>"
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    main "$@"
fi
