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
# Array to hold discovered docker-compose files relevant to the current action.
compose_files=()
# Variable to hold a single found compose file
found_compose_file=""
# List of deactivated services (from root .deactivated file)
deactivated_services=()

# Load deactivated services from root .deactivated file
load_deactivated_services() {
    local file=".deactivated"
    if [ -f "$file" ]; then
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            deactivated_services+=("$line")
        done < "$file"
    fi
}

# Check if a service is deactivated
is_deactivated() {
    local svc="$1"
    for d in "${deactivated_services[@]}"; do
        if [ "$d" = "$svc" ]; then
            return 0
        fi
    done
    return 1
}

# ===================================================================
# DISPLAY UTILITIES
# ===================================================================
# Color codes for consistent formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;90m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Print a styled header
print_header() {
    local title="$1"
    local color="${2:-$CYAN}"
    echo -e "\n${color}${BOLD}╭─────────────────────────────────────────────────────╮${NC}"
    echo -e "${color}${BOLD}│ $title${NC}"
    echo -e "${color}${BOLD}╰─────────────────────────────────────────────────────╯${NC}"
}

# Print a styled section
print_section() {
    local title="$1"
    local color="${2:-$BLUE}"
    echo -e "\n${color}${BOLD}▶ $title${NC}"
}

# Print a styled subsection
print_subsection() {
    local title="$1"
    local color="${2:-$GRAY}"
    echo -e "\n${color}  ▸ $title${NC}"
}

# Print success message
print_success() {
    local message="$1"
    echo -e "${GREEN}✓ $message${NC}"
}

# Print warning message
print_warning() {
    local message="$1"
    echo -e "${YELLOW}⚠ $message${NC}"
}

# Print error message
print_error() {
    local message="$1"
    echo -e "${RED}✗ $message${NC}"
}

# Print info message
print_info() {
    local message="$1"
    echo -e "${BLUE}ℹ $message${NC}"
}

# Print a progress message
print_progress() {
    local message="$1"
    echo -e "${MAGENTA}⟳ $message${NC}"
}

# Print a summary box
print_summary() {
    local title="$1"
    shift
    local lines=("$@")
    
    # Calculate the maximum width needed
    local max_width=0
    local title_width=$((${#title} + 4)) # "╭─ " + title + " ─╮"
    
    if [ $title_width -gt $max_width ]; then
        max_width=$title_width
    fi
    
    # Check each line width (accounting for color codes)
    for line in "${lines[@]}"; do
        # Remove color codes for length calculation
        local clean_line=$(echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g')
        local line_width=$((${#clean_line} + 2)) # "│ " + content
        if [ $line_width -gt $max_width ]; then
            max_width=$line_width
        fi
    done
    
    # Ensure minimum width
    if [ $max_width -lt 40 ]; then
        max_width=40
    fi
    
    # Create dynamic borders
    local top_border="╭─ $title "
    local remaining_width=$((max_width - ${#top_border} - 1))
    local bottom_border="╰"
    
    # Fill remaining space with dashes
    for ((i=0; i<remaining_width; i++)); do
        top_border="${top_border}─"
    done
    top_border="${top_border}╮"
    
    # Create bottom border
    for ((i=0; i<max_width-2; i++)); do
        bottom_border="${bottom_border}─"
    done
    bottom_border="${bottom_border}╯"
    
    echo -e "\n${CYAN}${BOLD}${top_border}${NC}"
    for line in "${lines[@]}"; do
        echo -e "${CYAN}│${NC} $line"
    done
    echo -e "${CYAN}${BOLD}${bottom_border}${NC}"
}

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
        # echo "Loading environment from: $env_file"
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
    if [ $env_files_found -gt 0 ]; then
        print_info "Loaded $env_files_found environment file(s)"
    fi
    return 0
}

# Loads environment files for a specific service context
# Always loads root .env, then service's .env
load_service_env_files() {
    local service_name="$1"
    local compose_file_path="$2"
    local env_files_loaded_count=0

    # echo "Loading .env files for service '$service_name'"

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
    if [ $env_files_loaded_count -gt 0 ]; then
        print_info "Loaded $env_files_loaded_count .env file(s) for $service_name"
    fi
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

    # Exclude any path containing /data/ or /config/ (at any depth)
    local exclude_args=(-not -path "*/data/*" -not -path "*/config/*")

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
    done < <(find . \( "${find_paths_args[@]}" \) "${exclude_args[@]}" -print0 2>/dev/null | sort -uz)


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
        print_subsection "$prefix_message"
    fi

    if [ ${#compose_files[@]} -eq 0 ]; then
        print_warning "No Docker Compose files found matching the criteria"
        return 1
    fi

    print_info "Found ${#compose_files[@]} Docker Compose file(s):"
    for file_path in "${compose_files[@]}"; do
        echo -e "  ${GRAY}• ${CYAN}$file_path${NC}"
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
    # Load deactivated services list
    load_deactivated_services
    # If explicitly requesting a deactivated service, warn but proceed
    if [ -n "$service_filter" ] && [ "$service_filter" != "all" ] && is_deactivated "$service_filter"; then
        print_warning "Service '$service_filter' is deactivated; proceeding since explicitly requested."
    fi
    print_header "OneStack Auto Startup: ${service_filter:-all services}" "$GREEN"

    # Ensure networks exist (defer to network action or ensure it's called)
    print_section "Network Setup" "$MAGENTA"
    print_progress "Ensuring networks are created..."
    # Assuming action_network handles its own .env loading or global is sufficient
    action_network # This might need to be more selective or handled differently
    if [ $? -ne 0 ]; then
        print_error "Network setup failed"
        # exit 1 # Decide if up should fail completely if network fails
    fi

    # Load all .env files if no specific service, otherwise service-specific will be handled per service
    if [ -z "$service_filter" ]; then
        print_section "Environment Setup" "$BLUE"
        load_all_env_files || exit 1
    fi

    print_section "Service Discovery" "$CYAN"
    discover_compose_files "$service_filter"
    if ! print_discovered_files "Discovering Docker Compose files for startup..."; then
        print_error "No Docker Compose files found for: ${service_filter:-all services}"
        return 1
    fi

    local temp_dir
    temp_dir="/tmp/onestack-startup-$$"
    mkdir -p "$temp_dir"
    trap 'rm -rf "$temp_dir"' EXIT

    # Skip deactivated services when no specific filter
    if [ -z "$service_filter" ]; then
        local kept=()
        local skipped=()
        for f in "${compose_files[@]}"; do
            local svc=$(get_service_name "$f")
            if is_deactivated "$svc"; then
                skipped+=("$svc")
            else
                kept+=("$f")
            fi
        done
        if [ ${#skipped[@]} -gt 0 ]; then
            print_warning "Skipping deactivated services: ${skipped[*]}"
        fi
        compose_files=("${kept[@]}")
    fi
    # Function to pull/build a single service
    _pull_build_service_up() {
        local compose_file="$1"
        local service_name="$2" # Extracted from compose_file path
        local status_file="$temp_dir/$service_name.pull.status"
        local log_file="$temp_dir/$service_name.pull.log"

        # Specific env loading for this service before pull/build
        load_service_env_files "$service_name" "$compose_file"

        echo "RUNNING" > "$status_file"
        echo -e "${GRAY}  Pulling/Building images for ${CYAN}$service_name${NC}..."
        # Run docker compose commands with project directory set to service's directory
        local service_project_dir
        service_project_dir=$(dirname "$compose_file")
        if docker compose -f "$compose_file" -p "${service_name}" pull --ignore-buildable > "$log_file" 2>&1 && \
           docker compose -f "$compose_file" -p "${service_name}" build --quiet >> "$log_file" 2>&1; then
            echo "SUCCESS" > "$status_file"
            print_success "$service_name images ready"
        else
            echo "FAILED" > "$status_file"
            print_warning "$service_name image pull/build had issues (may still work)"
            echo -e "${GRAY}    Pull/build details for $service_name (see $log_file):${NC}"
            grep -E "(ERROR|error|Error|failed|Failed|pull|Pull|not found)" "$log_file" | tail -5 | sed 's/^/    /'
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
        echo -e "${GRAY}  Starting ${CYAN}$service_name${NC}..."
        # Run docker compose commands with project directory set to service's directory
        local service_project_dir
        service_project_dir=$(dirname "$compose_file")

        # Use -p (project name) to ensure containers are uniquely named, especially if multiple compose files define same service names
        # Project name derived from service name to ensure uniqueness
        if docker compose -f "$compose_file" -p "${service_name}" up -d > "$log_file" 2>&1; then
            echo "SUCCESS" > "$status_file"
            print_success "$service_name started successfully"
        else
            echo "FAILED" > "$status_file"
            print_error "$service_name failed to start"
            echo -e "${GRAY}    Error details for $service_name (see $log_file):${NC}"
            tail -5 "$log_file" | sed 's/^/    /'
        fi
    }

    print_section "Image Preparation" "$YELLOW"
    print_progress "Pulling and building images in parallel (max $MAX_PARALLEL_JOBS concurrent)..."
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
    print_success "All image pull/build processes completed"

    print_section "Service Startup" "$GREEN"
    print_progress "Starting services in parallel (max $MAX_PARALLEL_JOBS concurrent)..."
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
    print_success "All startup processes initiated"

    # Ensure all background processes have completed and output is flushed
    wait
    sleep 1

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

    # Summary
    local summary_lines=()
    summary_lines+=("${GREEN}Successfully started: $successful_services service(s)${NC}")
    summary_lines+=("${RED}Failed to start: $failed_services service(s)${NC}")
    
    if [ $failed_services -gt 0 ]; then
        summary_lines+=("${YELLOW}Some services failed to start. Check the logs above for details.${NC}")
    fi
    
    print_summary "Startup Summary" "${summary_lines[@]}"

    if [ $failed_services -gt 0 ]; then
        return 1 # Indicate failure
    else
        print_success "All specified services are up and running!"
    fi
    return 0
}


action_logs() {
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
                    print_error "--tail requires a number"
                    return 1
                fi
                ;;
            *) # Any other options are passed directly to docker compose logs
                additional_opts+=("$1")
                shift
                ;;
        esac
    done

    # Load deactivated services list
    load_deactivated_services
    print_header "OneStack Service Logs: ${service_target}" "$CYAN"
    print_info "Service: '${service_target}', Follow: '${follow_logs:-off}', Tail: '${tail_lines}', Additional Options: '${additional_opts[*]}'"

    if [ "$service_target" == "all" ]; then
        print_section "Environment Setup" "$BLUE"
        print_progress "Loading all environment files for combined logs..."
        load_all_env_files # Load all for combined view, individual services might have specifics but this is for general view

        print_section "Service Discovery" "$CYAN"
        discover_compose_files "all"
        if ! print_discovered_files "Gathering logs for all services:"; then
            return 1
        fi

        if [ ${#compose_files[@]} -eq 0 ]; then
            print_warning "No services found to show logs for"
            return 1
        fi

        local compose_cmd_args=()
        # Skip deactivated services
        local kept=()
        local skipped=()
        for f in "${compose_files[@]}"; do
            local svc=$(get_service_name "$f")
            if is_deactivated "$svc"; then
                skipped+=("$svc")
            else
                kept+=("$f")
            fi
        done
        if [ ${#skipped[@]} -gt 0 ]; then
            print_warning "Skipping deactivated services for logs: ${skipped[*]}"
        fi
        for f in "${kept[@]}"; do
            compose_cmd_args+=("-f" "$f")
        done

        print_section "Log Output" "$MAGENTA"
        print_info "Showing combined logs (tail: $tail_lines${follow_logs:+, follow mode}). Press Ctrl+C to exit."
        # shellcheck disable=SC2086 # $follow_logs should not be quoted if empty
        docker compose ${compose_cmd_args[@]} logs --tail="$tail_lines" $follow_logs "${additional_opts[@]}"

    else
        # Specific service target
        # If specific deactivated, warn
        if is_deactivated "$service_name_for_logs"; then
            print_warning "Service '$service_name_for_logs' is deactivated; showing logs anyway."
        fi
        print_section "Service Discovery" "$CYAN"
        find_service_compose_file "$service_name_for_logs"
        if [ -z "$found_compose_file" ]; then
            print_error "Service '$service_name_for_logs' not found"
            # Try to list available services
            discover_compose_files "all"
            print_subsection "Available services (based on directory names):"
            for cf in "${compose_files[@]}"; do
                echo -e "  ${GRAY}• ${CYAN}$(get_service_name "$cf")${NC}"
            done
            return 1
        fi

        local service_actual_name
        service_actual_name=$(get_service_name "$found_compose_file")
        
        print_section "Environment Setup" "$BLUE"
        load_service_env_files "$service_actual_name" "$found_compose_file"

        print_section "Log Output" "$MAGENTA"
        print_info "Showing logs for service: $service_actual_name (file: $found_compose_file, tail: $tail_lines${follow_logs:+, follow mode}). Press Ctrl+C to exit."
        # Use -p project name to ensure logs are for the correct instance if names are reused
        # shellcheck disable=SC2086
        docker compose -f "$found_compose_file" -p "$service_actual_name" logs --tail="$tail_lines" $follow_logs "${additional_opts[@]}"
    fi
    return 0
}




action_down() {
    local service_filter="$1"
    print_header "OneStack Auto Shutdown: ${service_filter:-all services}" "$RED"

    # Load all .env files if no specific service, otherwise service-specific will be handled per service
    if [ -z "$service_filter" ]; then
        print_section "Environment Setup" "$BLUE"
        load_all_env_files || exit 1 # Essential for proper shutdown variables
    fi

    print_section "Service Discovery" "$CYAN"
    discover_compose_files "$service_filter"
    if ! print_discovered_files "Discovering Docker Compose files for shutdown..."; then
        print_info "Nothing to stop for: ${service_filter:-all services}"
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
        echo -e "${GRAY}  Stopping ${CYAN}$service_name${NC}..."
        # Use -p (project name) matching the one used in 'up'
        if timeout "$SHUTDOWN_TIMEOUT" docker compose -f "$compose_file" -p "${service_name}" down > "$log_file" 2>&1; then
            echo "SUCCESS" > "$status_file"
            print_success "$service_name stopped successfully"
        else
            local exit_code=$?
            echo "FAILED" > "$status_file"
            if [ $exit_code -eq 124 ]; then # Timeout specific exit code
                print_error "$service_name failed to stop (timeout after ${SHUTDOWN_TIMEOUT}s)"
            else
                print_error "$service_name failed to stop (error)"
            fi
            echo -e "${GRAY}    Error details for $service_name (see $log_file):${NC}"
            cat "$log_file" | sed 's/^/    /'
        fi
    }

    print_section "Service Shutdown" "$YELLOW"
    print_progress "Stopping services in parallel (max $MAX_PARALLEL_JOBS concurrent, ${SHUTDOWN_TIMEOUT}s timeout)..."
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
    print_success "All shutdown processes initiated"

    # Ensure all background processes have completed and output is flushed
    wait
    sleep 1

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

    # Summary
    local summary_lines=()
    summary_lines+=("${GREEN}Successfully stopped: $successful_services service(s)${NC}")
    summary_lines+=("${RED}Failed to stop: $failed_services service(s)${NC}")
    
    if [ $failed_services -gt 0 ]; then
        summary_lines+=("${YELLOW}Some services failed to stop. Check the logs above for details.${NC}")
        summary_lines+=("${GRAY}You may need to stop them manually (e.g. docker stop <container_id>)${NC}")
    fi
    
    print_summary "Shutdown Summary" "${summary_lines[@]}"

    if [ $failed_services -gt 0 ]; then
        return 1 # Indicate failure
    else
        print_success "All specified services have been stopped successfully!"
    fi
    return 0
}

action_status() {
    local service_filter="$1"
    # Load deactivated services list
    load_deactivated_services
    
    print_header "OneStack Service Status: ${service_filter:-all services}" "$CYAN"
    print_info "Status based on 'docker compose ps' output"

    # Discover all compose files. Status should generally reflect everything.
    # Pass "all" to discover_compose_files to get all services.
    # The original script had "false" for include_shared, but status should ideally show all.
    # Let's assume "all" is the desired behavior for a comprehensive status.
    print_section "Service Discovery" "$CYAN"
    discover_compose_files "${service_filter:-all}"

    if [ ${#compose_files[@]} -eq 0 ]; then
        print_warning "No Docker Compose files found matching filter: ${service_filter:-all}"
        return 1
    fi
    
    print_section "Discovered Services" "$CYAN"
    for file_path in "${compose_files[@]}"; do
        local svc=$(get_service_name "$file_path")
        local status_text=""
        if is_deactivated "$svc"; then
            status_text="${RED}[DEACTIVATED]${NC}"
        else
            status_text="${GREEN}[ACTIVE]${NC}"
        fi
        echo -e "  ${GRAY}• ${CYAN}$svc${NC} $status_text ${GRAY}($file_path)${NC}"
    done
    
    # Show deactivated services list
    if [ ${#deactivated_services[@]} -gt 0 ]; then
        print_section "Deactivated Services" "$YELLOW"
        for svc in "${deactivated_services[@]}"; do
            echo -e "  ${GRAY}• ${YELLOW}$svc${NC}"
        done
    else
        print_info "No services are deactivated"
    fi

    print_section "Service Status Details" "$CYAN"

    local overall_issue_found=0

    for file_path in "${compose_files[@]}"; do
        local service_name_from_path
        service_name_from_path=$(get_service_name "$file_path")

        # Load .env specific to this service context for 'docker compose ps'
        load_service_env_files "$service_name_from_path" "$file_path"

        print_subsection "Service: $service_name_from_path" "$GREEN"
        echo -e "${GRAY}  Configuration: ${CYAN}$file_path${NC}"
        echo -e "${BLUE}  ─────────────────────────────────────────────────────${NC}"

        # Get status output, using the service name as project name for consistency
        # Using --all to show stopped containers as well.
        local status_output
        status_output=$(docker compose -f "$file_path" -p "$service_name_from_path" ps --all --format "table {{.Name}}\t{{.State}}\t{{.Status}}\t{{.Health}}")

        if [ -z "$status_output" ]; then
            print_warning "No services defined or running for this configuration"
            continue
        fi

        local header_processed=0
        while IFS= read -r line; do
            if [ $header_processed -eq 0 ]; then
                echo -e "${BOLD}  $line${NC}" # Print header as is
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
            echo -e "${line_color}  $line${NC}"
        done <<< "$status_output"
    done

    print_section "Status Summary" "$CYAN"
    if [ $overall_issue_found -ne 0 ]; then
        print_error "Some services are unhealthy or not running as expected. Please review the status above."
        return 1 # Indicate that there might be issues
    else
        print_success "All services are running as expected"
    fi
    return 0
}

action_restart() {
    local service_filter="$1" # Optional: specific service/group to restart
    # Load deactivated services list
    load_deactivated_services
    # If explicitly requesting a deactivated service, warn but proceed
    if [ -n "$service_filter" ] && [ "$service_filter" != "all" ] && is_deactivated "$service_filter"; then
        print_warning "Service '$service_filter' is deactivated; proceeding with restart since explicitly requested."
    fi
    print_header "OneStack Service Restart: ${service_filter:-all services}" "$MAGENTA"

    # The restart action will effectively call 'down' then 'up'
    # for the specified services or all services.
    # Environment loading and service discovery are handled by action_down and action_up.

    print_section "Phase 1: Stopping Services" "$RED"
    action_down "$service_filter"
    local down_status=$? # Capture exit status of down action

    if [ $down_status -ne 0 ]; then
        print_warning "Services failed to stop cleanly. Proceeding with startup, but there might be issues."
        # Depending on desired strictness, could exit here:
        # echo "❌ Aborting restart due to shutdown failures."
        # return 1
    else
        print_success "Services stopped successfully"
    fi

    print_section "Phase 2: Starting Services" "$GREEN"
    action_up "$service_filter"
    local up_status=$? # Capture exit status of up action

    if [ $up_status -ne 0 ]; then
        print_error "Some services failed to start during restart"
        return 1
    else
        print_success "Services restarted successfully!"
    fi

    return 0
}

action_network() {
    print_header "OneStack Network Management" "$BLUE"

    # Load all environment variables first to ensure all network names are available.
    # This is crucial as network names can be defined in the root .env or service-specific .env files,
    # and action_up calls action_network before individual service .env files might be loaded by action_up's loop.
    print_section "Environment Setup" "$CYAN"
    load_all_env_files || return 1

    local networks_processed_count=0
    local networks_created_count=0
    local networks_failed_count=0

    # Internal function to create a single network
    _create_single_network() {
        local network_name="$1"
        if [ -z "$network_name" ]; then
            print_warning "Network name is empty, skipping creation"
            return 1 # Indicate skip/fail for this attempt
        fi

        # Check if network already exists
        if docker network inspect "$network_name" >/dev/null 2>&1; then
            print_info "Network '$network_name' already exists"
            return 0 # Success, already exists
        else
            echo -e "${GRAY}  Creating network: ${CYAN}$network_name${NC}"
            if [ "$network_name" = "$INTERNAL_NETWORK_NAME" ]; then
                if docker network create \
                  --driver bridge \
                  --subnet 172.20.0.0/16 \
                  --gateway 172.20.0.1 \
                  "$network_name" >/dev/null; then
                    print_success "Network '$network_name' created successfully with custom options"
                    ((networks_created_count++))
                    return 0 # Success, created
                else
                    print_error "Failed to create network '$network_name'"
                    ((networks_failed_count++))
                    return 1 # Failure to create
                fi
            else
                if docker network create "$network_name" >/dev/null; then # Suppress verbose output from docker
                    print_success "Network '$network_name' created successfully"
                    ((networks_created_count++))
                    return 0 # Success, created
                else
                    print_error "Failed to create network '$network_name'"
                    ((networks_failed_count++))
                    return 1 # Failure to create
                fi
            fi
        fi
    }

    print_section "Network Discovery" "$YELLOW"
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
        print_warning "No network names found in environment variables (e.g., WEB_NETWORK_NAME)"
        # This might not be an error if no services require specific networks yet
        # For now, let's just inform and proceed.
    else
        print_info "Found network names to ensure existence: ${declared_networks[*]}"
    fi

    print_section "Network Creation" "$GREEN"
    for net_name in "${declared_networks[@]}"; do
        _create_single_network "$net_name"
        ((networks_processed_count++))
    done

    # Summary
    local summary_lines=()
    summary_lines+=("${BLUE}Networks processed: $networks_processed_count${NC}")
    summary_lines+=("${GREEN}Networks newly created: $networks_created_count${NC}")
    summary_lines+=("${RED}Networks failed to create: $networks_failed_count${NC}")
    
    if [ $networks_failed_count -gt 0 ]; then
        summary_lines+=("${YELLOW}Some networks failed to create. This might cause issues for services.${NC}")
    elif [ ${#declared_networks[@]} -eq 0 ] && [ $networks_created_count -eq 0 ]; then
        summary_lines+=("${GRAY}No specific networks were defined or created. Services will use default Docker networks.${NC}")
    fi
    
    print_summary "Network Setup Summary" "${summary_lines[@]}"

    if [ $networks_failed_count -gt 0 ]; then
        return 1 # Indicate failure
    fi

    print_success "Network setup completed"
    return 0
}

action_clean() {
    print_header "OneStack Auto Cleanup" "$YELLOW"
    local extra_args="$@" # Capture any extra args like --all-volumes or --remove-images

    # Step 1: Stop all services
    print_section "Phase 1: Stopping Services" "$RED"
    action_down "all" # "all" ensures it tries to stop everything defined
    if [ $? -ne 0 ]; then
        print_warning "Some services may not have stopped properly. Continuing cleanup."
    else
        print_success "All services stopped"
    fi

    # Step 2: Clean up defined networks
    # Networks should be removed after services are down.
    # load_all_env_files is called by action_network if needed, or here explicitly
    print_section "Phase 2: Network Cleanup" "$BLUE"
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
        print_info "Attempting to remove defined networks: ${declared_networks_to_remove[*]}"
        for net_name in "${declared_networks_to_remove[@]}"; do
            if docker network inspect "$net_name" >/dev/null 2>&1; then
                echo -e "${GRAY}  Removing network: ${CYAN}$net_name${NC}"
                if docker network rm "$net_name" >/dev/null 2>&1; then
                    print_success "Network '$net_name' removed"
                    ((networks_removed_count++))
                else
                    print_warning "Could not remove network '$net_name' (may still be in use)"
                fi
            else
                print_info "Network '$net_name' not found (already removed or never created)"
            fi
        done
    else
        print_info "No specific networks found defined in .env files to target for removal"
    fi

    # Step 3: Clean up general unused Docker resources
    print_section "Phase 3: Docker Resource Cleanup" "$MAGENTA"

    print_progress "Removing stopped containers..."
    docker container prune -f

    # By default, prune only anonymous volumes.
    # Add a flag e.g. `make clean ARGS=--all-volumes` or `onestack.sh clean --all-volumes` to prune all unused volumes.
    if [[ " ${extra_args[*]} " =~ " --all-volumes " ]]; then
        print_warning "Removing all unused volumes (including named ones not attached to any container)..."
        print_warning "This will remove ALL unused volumes. Ensure no important data is in unattached named volumes."
        read -p "$(echo -e "${YELLOW}Proceed with removing all unused volumes? (yes/NO): ${NC}")" -r confirmation
        if [[ "$confirmation" == "yes" ]]; then
            docker volume prune -f
            print_success "All unused volumes pruned"
        else
            print_info "Skipping pruning of all unused volumes"
            print_progress "Pruning only anonymous unused volumes..."
            docker volume ls -qf dangling=true | xargs -r docker volume rm
        fi
    else
        print_progress "Removing unused anonymous volumes (use 'clean --all-volumes' to include named)..."
        docker volume ls -qf dangling=true | xargs -r docker volume rm # More targeted anonymous volume removal
    fi

    print_progress "Removing unused networks (Docker's general prune)..."
    docker network prune -f

    # Optional: Image pruning
    # Add a flag e.g. `make clean ARGS=--remove-images` or `onestack.sh clean --remove-images`
    if [[ " ${extra_args[*]} " =~ " --remove-images " ]]; then
        print_progress "Removing unused images (dangling and unreferenced)..."
        docker image prune -a -f # -a prunes all unused images, not just dangling
    elif [[ " ${extra_args[*]} " =~ " --remove-dangling-images " ]]; then
        print_progress "Removing dangling images..."
        docker image prune -f
    else
        print_info "Skipping image pruning. Use 'clean --remove-dangling-images' or 'clean --remove-images' for image cleanup"
    fi

    # Summary
    local summary_lines=()
    summary_lines+=("${BLUE}Defined networks targeted for removal: ${#declared_networks_to_remove[@]}${NC}")
    summary_lines+=("${GREEN}Defined networks actually removed: $networks_removed_count${NC}")
    summary_lines+=("${CYAN}Docker resource pruning completed (containers, anonymous volumes, networks)${NC}")
    summary_lines+=("${GRAY}For more aggressive cleanup, consider 'docker system prune -a --volumes' (⚠️ highly destructive)${NC}")
    
    print_summary "Cleanup Summary" "${summary_lines[@]}"

    print_success "Cleanup process finished!"
    return 0
}

# ================================================================================
# ACTION: shell
# Opens an interactive shell inside a running service container.
# Usage: onestack.sh shell <service_name>
# ================================================================================
action_update() {
    local service_filter="$1"
    # Load deactivated services list
    load_deactivated_services
    # If explicitly requesting a deactivated service, warn but proceed
    if [ -n "$service_filter" ] && [ "$service_filter" != "all" ] && is_deactivated "$service_filter"; then
        print_warning "Service '$service_filter' is deactivated; proceeding since explicitly requested."
    fi
    print_header "OneStack Update: ${service_filter:-all services}" "$GREEN"

    # Load all .env files if no specific service, otherwise service-specific will be handled per service
    if [ -z "$service_filter" ]; then
        print_section "Environment Setup" "$BLUE"
        load_all_env_files || exit 1
    fi

    print_section "Service Discovery" "$CYAN"
    discover_compose_files "$service_filter"
    if ! print_discovered_files "Discovering Docker Compose files for update..."; then
        print_error "No Docker Compose files found for: ${service_filter:-all services}"
        return 1
    fi

    local temp_dir
    temp_dir="/tmp/onestack-update-$$"
    mkdir -p "$temp_dir"
    trap 'rm -rf "$temp_dir"' EXIT

    # Filter out deactivated services if no specific service requested
    if [ -z "$service_filter" ]; then
        local kept=()
        local skipped=()
        for f in "${compose_files[@]}"; do
            local current_service_name
            current_service_name=$(basename "$(dirname "$f")")
            if is_deactivated "$current_service_name"; then
                skipped+=("$current_service_name")
            else
                kept+=("$f")
            fi
        done
        if [ ${#skipped[@]} -gt 0 ]; then
            print_warning "Skipping deactivated services: ${skipped[*]}"
        fi
        compose_files=("${kept[@]}")
    fi

    # Function to pull images for a single service
    _pull_service_update() {
        local compose_file="$1"
        local service_name="$2"
        local status_file="$temp_dir/$service_name.pull.status"
        local log_file="$temp_dir/$service_name.pull.log"

        # Specific env loading for this service before pull
        load_service_env_files "$service_name" "$compose_file"

        echo "RUNNING" > "$status_file"
        echo -e "${GRAY}  Pulling images for ${CYAN}$service_name${NC}..."

        {
            echo "=== Pulling images for $service_name ==="
            docker compose -f "$compose_file" pull
            echo "=== Pull completed with exit code: $? ==="
        } > "$log_file" 2>&1

        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo "SUCCESS" > "$status_file"
            echo -e "${GREEN}✓ Successfully pulled images for ${CYAN}$service_name${NC}"
        else
            echo "FAILED" > "$status_file"
            echo -e "${RED}✗ Failed to pull images for ${CYAN}$service_name${NC} (exit code: $exit_code)"
        fi
        return $exit_code
    }

    print_section "Image Update" "$YELLOW"
    print_progress "Pulling images in parallel (max $MAX_PARALLEL_JOBS concurrent)..."

    local job_count=0
    local pids=()
    for file_path in "${compose_files[@]}"; do
        local current_service_name
        current_service_name=$(basename "$(dirname "$file_path")")

        if [ $job_count -ge $MAX_PARALLEL_JOBS ]; then
            wait "${pids[0]}"
            pids=("${pids[@]:1}")
            ((job_count--))
        fi

        _pull_service_update "$file_path" "$current_service_name" &
        pids+=($!)
        ((job_count++))
    done

    # Wait for all remaining jobs
    for pid in "${pids[@]}"; do
        wait "$pid"
    done

    print_section "Update Summary" "$CYAN"
    local success_count=0
    local failed_count=0
    local failed_services=()
    for file_path in "${compose_files[@]}"; do
        local current_service_name
        current_service_name=$(basename "$(dirname "$file_path")")
        local status_file="$temp_dir/$current_service_name.pull.status"
        if [ -f "$status_file" ]; then
            local status
            status=$(cat "$status_file")
            if [ "$status" = "SUCCESS" ]; then
                ((success_count++))
            else
                ((failed_count++))
                failed_services+=("$current_service_name")
            fi
        fi
    done

    echo -e "${GREEN}✓ Successfully updated: $success_count services${NC}"
    if [ $failed_count -gt 0 ]; then
        echo -e "${RED}✗ Failed to update: $failed_count services${NC}"
        echo -e "${RED}  Failed services: ${failed_services[*]}${NC}"
        return 1
    fi
    echo -e "${CYAN}All images have been updated successfully!${NC}"
}

action_shell() {
    local service="$1"
    if [ -z "$service" ]; then
        print_error "Usage: $0 shell <service_name>"
        return 1
    fi

    # Locate compose file for the service
    discover_compose_files "$service"
    if [ ${#compose_files[@]} -eq 0 ]; then
        print_error "Service '$service' not found"
        return 1
    fi

    # Determine container name via docker compose, fallback to service name
    local container
    container=$(docker compose -f "$found_compose_file" ps -q "$service" \
        | xargs -r docker inspect --format '{{.Name}}' \
        | sed 's/^\/\(.*\)$/\1/')
    if [ -z "$container" ]; then
        container="$service"
    fi
    # Ensure the container is running
    if ! docker ps --filter "name=^${container}$" --format '{{.Names}}' \
        | grep -xq "$container"; then
        print_error "Container '$container' is not running"
        return 1
    fi

    print_section "Opening shell in container '$container'…" "$CYAN"
    # Try bash, else fallback to sh
    if docker exec "$container" command -v bash &>/dev/null; then
        docker exec -it "$container" bash
    else
        docker exec -it "$container" sh
    fi
}

# ===================================================================
# INTERNAL UTILITY FUNCTIONS
# These are internal debugging/testing functions for troubleshooting.
# ===================================================================

# Internal function to test service discovery
action__discover() {
    local service_filter="$1"
    load_deactivated_services
    print_header "OneStack Service Discovery (Internal)" "$GRAY"
    print_info "Filter: '${service_filter:-all}'"
    
    discover_compose_files "$service_filter"
    
    if [ ${#compose_files[@]} -eq 0 ]; then
        print_warning "No Docker Compose files found matching filter: ${service_filter:-all}"
        return 1
    fi
    
    print_section "Discovered Services" "$CYAN"
    for file_path in "${compose_files[@]}"; do
        local svc=$(get_service_name "$file_path")
        local status_text=""
        if is_deactivated "$svc"; then
            status_text="${RED}[DEACTIVATED]${NC}"
        else
            status_text="${GREEN}[ACTIVE]${NC}"
        fi
        echo -e "  ${GRAY}• ${CYAN}$svc${NC} $status_text ${GRAY}($file_path)${NC}"
    done
    
    # Show deactivated services list
    if [ ${#deactivated_services[@]} -gt 0 ]; then
        print_section "Deactivated Services" "$YELLOW"
        for svc in "${deactivated_services[@]}"; do
            echo -e "  ${GRAY}• ${YELLOW}$svc${NC}"
        done
    else
        print_info "No services are deactivated"
    fi
    
    return 0
}

# Internal function to test environment loading
action__load_envs() {
    local service_name="$1"
    local compose_file="$2"
    
    if [ -z "$service_name" ]; then
        print_header "OneStack Environment Loading (Internal)" "$GRAY"
        print_info "Loading all environment files..."
        load_all_env_files
    else
        print_header "OneStack Environment Loading for $service_name (Internal)" "$GRAY"
        if [ -z "$compose_file" ]; then
            print_error "Usage: _load_envs <service_name> <compose_file_path>"
            return 1
        fi
        print_info "Loading environment for service: $service_name"
        print_info "Compose file: $compose_file"
        load_service_env_files "$service_name" "$compose_file"
    fi
    
    print_success "Environment loading completed"
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
        up)       action_up "$@" ;;
        down)     action_down "$@" ;;
        logs)     action_logs "$@" ;;
        status)   action_status "$@" ;;
        restart)  action_restart "$@" ;;
        update)   action_update "$@" ;;
        network)  action_network "$@" ;;
        clean)    action_clean "$@" ;;
        shell)    action_shell "$@" ;;  # Added shell action
        # Internal/utility functions
        _discover) action__discover "$@" ;;
        _load_envs) action__load_envs "$@" ;;
        *)
            print_header "OneStack Usage" "$WHITE"
            echo -e "${BOLD}Usage:${NC} $0 {up|down|logs|status|restart|update|network|clean} [service_name/filter] [options...]"
            echo ""
            echo -e "${CYAN}${BOLD}Main Commands:${NC}"
            echo -e "  ${GREEN}up${NC}       - Start services"
            echo -e "  ${RED}down${NC}     - Stop services"
            echo -e "  ${YELLOW}logs${NC}     - Show service logs"
            echo -e "  ${BLUE}status${NC}   - Show service status"
            echo -e "  ${MAGENTA}restart${NC}  - Restart services"
            echo -e "  ${YELLOW}update${NC}   - Pull latest images"
            echo -e "  ${CYAN}network${NC}  - Manage networks"
            echo -e "  ${YELLOW}clean${NC}    - Clean up resources"
            echo ""
            echo -e "${GRAY}${BOLD}Internal utilities:${NC}"
            echo -e "  ${GRAY}_discover [service_filter]${NC}"
            echo -e "  ${GRAY}_load_envs <service_name> <compose_file_path>${NC}"
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    main "$@"
fi
