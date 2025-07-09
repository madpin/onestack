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
ONESTACK_DISABLED_CONF_FILE="onestack.disabled.conf"
ONESTACK_DISABLED_LOCAL_CONF_FILE="onestack.disabled.local.conf"

# Array to hold discovered docker-compose files relevant to the current action.
compose_files=()
# Variable to hold a single found compose file
found_compose_file=""
# Array to hold the list of disabled projects
disabled_projects_list=()

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

action_stats() {
    local service_filter="$1" # Optional: specific service/group to show stats for
    print_header "OneStack Service Stats: ${service_filter:-all services}" "$GREEN"

    # Discover services - always discover all or specific, do not use disable list for stats
    print_section "Service Discovery for Stats" "$CYAN"
    discover_compose_files "$service_filter" "" # Empty exclude list

    if ! print_discovered_files "Discovering services to fetch stats for..."; then
        if [ -n "$service_filter" ] && [ "$service_filter" != "all" ]; then
            print_error "No Docker Compose files found for specified service: $service_filter"
            return 1
        elif [ -z "$service_filter" ] || [ "$service_filter" == "all" ]; then
            print_info "No services found to fetch stats for."
            return 0
        fi
    fi

    if [ ${#compose_files[@]} -eq 0 ]; then
        print_info "No services found to fetch stats for after discovery."
        return 0
    fi

    print_section "Collecting Container IDs" "$BLUE"
    local container_ids=()
    for file_path in "${compose_files[@]}"; do
        local service_name_from_path
        service_name_from_path=$(get_service_name "$file_path")

        # Load .env specific to this service context for 'docker compose ps -q'
        load_service_env_files "$service_name_from_path" "$file_path"

        print_progress "Getting container IDs for $service_name_from_path..."
        # Get running container IDs for the project
        # Silence errors for ps -q if no containers are running for a project
        local ids
        ids=$(docker compose -f "$file_path" -p "$service_name_from_path" ps -q 2>/dev/null)
        if [ -n "$ids" ]; then
            while IFS= read -r id; do
                # Check if ID is already in the list to avoid duplicates if multiple compose files manage same container (unlikely with -p)
                if [[ ! " ${container_ids[*]} " =~ " ${id} " ]]; then
                    container_ids+=("$id")
                fi
            done <<< "$ids"
        fi
    done

    if [ ${#container_ids[@]} -eq 0 ]; then
        print_warning "No running containers found for the specified services."
        return 0
    fi

    print_section "Displaying Docker Stats" "$MAGENTA"
    print_info "Showing stats for ${#container_ids[@]} container(s). Press Ctrl+C to exit if streaming, or will show once if --no-stream."
    # By default, docker stats streams. Add --no-stream for a one-time output.
    # The request was "more visual appealing", initially just pass through. Can be enhanced later.
    docker stats --no-stream "${container_ids[@]}"

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
# Reads disabled project names from config files and ONESTACK_DISABLED_PROJECTS env var.
# Populates the global 'disabled_projects_list' array.
# Comments (#) and empty lines in files are ignored.
get_disabled_projects_list() {
    disabled_projects_list=()
    local combined_list=()
    local project_name

    # Read from ONESTACK_DISABLED_CONF_FILE
    if [ -f "$ONESTACK_DISABLED_CONF_FILE" ]; then
        print_info "Reading disabled projects from $ONESTACK_DISABLED_CONF_FILE"
        while IFS= read -r line || [[ -n "$line" ]]; do
            line=$(echo "$line" | sed 's/#.*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') # Remove comments and trim whitespace
            if [ -n "$line" ]; then
                combined_list+=("$line")
            fi
        done < "$ONESTACK_DISABLED_CONF_FILE"
    fi

    # Read from ONESTACK_DISABLED_LOCAL_CONF_FILE
    if [ -f "$ONESTACK_DISABLED_LOCAL_CONF_FILE" ]; then
        print_info "Reading disabled projects from $ONESTACK_DISABLED_LOCAL_CONF_FILE"
        while IFS= read -r line || [[ -n "$line" ]]; do
            line=$(echo "$line" | sed 's/#.*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') # Remove comments and trim whitespace
            if [ -n "$line" ]; then
                combined_list+=("$line")
            fi
        done < "$ONESTACK_DISABLED_LOCAL_CONF_FILE"
    fi

    # Read from ONESTACK_DISABLED_PROJECTS environment variable (comma-separated)
    if [ -n "$ONESTACK_DISABLED_PROJECTS" ]; then
        print_info "Reading disabled projects from ONESTACK_DISABLED_PROJECTS environment variable"
        IFS=',' read -r -a env_disabled_projects <<< "$ONESTACK_DISABLED_PROJECTS"
        for project_name in "${env_disabled_projects[@]}"; do
            project_name=$(echo "$project_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//') # Trim whitespace
            if [ -n "$project_name" ]; then
                combined_list+=("$project_name")
            fi
        done
    fi

    # Deduplicate the list
    if [ ${#combined_list[@]} -gt 0 ]; then
        # Sort and unique
        # Use printf and sort -u to handle potential special characters in names robustly
        # Then read back into the array, careful with IFS and newlines
        local unique_sorted_list
        unique_sorted_list=$(printf "%s\n" "${combined_list[@]}" | sort -u)

        disabled_projects_list=() # Reset before populating
        while IFS= read -r project_name; do
            if [ -n "$project_name" ]; then # Ensure no empty strings from read
                 disabled_projects_list+=("$project_name")
            fi
        done <<< "$unique_sorted_list"
    fi

    if [ ${#disabled_projects_list[@]} -gt 0 ]; then
        print_info "Effective list of disabled projects for 'make up': ${disabled_projects_list[*]}"
    fi
}


# Discovers Docker Compose files in the workspace
# Usage: discover_compose_files [service_filter] [exclude_list_array_ref_name]
# Args:
#   service_filter: Optional. Filter results to match this service name or directory.
#                   If filter is "all", discovers all services.
#   exclude_list_array_ref_name: Optional. Name of an array containing project names to exclude.
#                                This is used only if service_filter is empty or "all".
# Sets the global array 'compose_files'
discover_compose_files() {
    local service_filter="$1"
    local exclude_list_ref="$2" # This will be the name of the array, e.g., "my_exclude_array"
    compose_files=() # Reset the global array

    local exclude_these_projects=()
    if [ -n "$exclude_list_ref" ]; then
        # Indirect expansion: eval to get the elements of the array passed by reference name
        # This is a bash way to pass array by reference (name)
        # Ensure the array name is safe if it comes from less controlled sources in future
        # For now, it's internally passed as "disabled_projects_list"
        eval "exclude_these_projects=(\"\${$exclude_list_ref[@]}\")"
    fi

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
    local discovered_temp_files=()
    while IFS= read -r -d $'\0' compose_file; do
        # Ensure the file path is relative to the project root
        local relative_path="${compose_file#"$current_dir"/}"
        relative_path="${relative_path#./}" # Ensure it doesn't start with ./ if already relative

        # Avoid duplicates
        if [[ ! " ${discovered_temp_files[*]} " =~ " ${relative_path} " ]]; then
            discovered_temp_files+=("$relative_path")
        fi
    done < <(find . \( "${find_paths_args[@]}" \) "${exclude_args[@]}" -print0 2>/dev/null | sort -uz)


    if [ ${#discovered_temp_files[@]} -eq 0 ] && [ -n "$service_filter" ] && [ "$service_filter" != "all" ]; then
        # If a specific service was requested but not found, try a broader search for that name
        # This handles cases where the service_filter is just "traefik" and the file is "traefik/docker-compose.yml"
        local fallback_find_results
        fallback_find_results=$(find . \( -path "*/$service_filter/docker-compose*.yml" -o -path "*/$service_filter/docker-compose*.yaml" \) "${exclude_args[@]}" -print0 2>/dev/null | sort -uz)
         while IFS= read -r -d $'\0' compose_file; do
            local relative_path="${compose_file#"$current_dir"/}"
            relative_path="${relative_path#./}"
            if [[ ! " ${discovered_temp_files[*]} " =~ " ${relative_path} " ]]; then
                discovered_temp_files+=("$relative_path")
            fi
        done < <(echo -n "$fallback_find_results")
    fi

    # Filter based on exclude_list if service_filter is empty or "all"
    if [ -z "$service_filter" ] || [ "$service_filter" == "all" ]; then
        if [ ${#exclude_these_projects[@]} -gt 0 ]; then
            for file_path in "${discovered_temp_files[@]}"; do
                local service_name_from_path
                service_name_from_path=$(get_service_name "$file_path")
                local exclude_it=0
                for excluded_proj in "${exclude_these_projects[@]}"; do
                    if [[ "$service_name_from_path" == "$excluded_proj" ]]; then
                        exclude_it=1
                        print_info "Excluding '$service_name_from_path' from 'all services' operation due to disable list."
                        break
                    fi
                done
                if [ $exclude_it -eq 0 ]; then
                    compose_files+=("$file_path")
                fi
            done
        else
            # No exclusion list, so add all discovered files
            compose_files=("${discovered_temp_files[@]}")
        fi
    else
        # Specific service filter is active, so exclusion list is ignored for this discovery
        compose_files=("${discovered_temp_files[@]}")
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
    print_header "OneStack Auto Startup: ${service_filter:-all services}" "$GREEN"

    # Ensure networks exist (defer to network action or ensure it's called)
    print_section "Network Setup" "$MAGENTA"
    print_progress "Ensuring networks are created..."
    action_network # This might need to be more selective or handled differently
    if [ $? -ne 0 ]; then
        print_error "Network setup failed"
        # exit 1 # Decide if up should fail completely if network fails
    fi

    local current_disabled_projects_ref_name=""
    # Load all .env files and disabled projects list if no specific service or "all"
    if [ -z "$service_filter" ] || [ "$service_filter" == "all" ]; then
        print_section "Environment Setup (Global & Disabled List)" "$BLUE"
        load_all_env_files # Load all .env files first
        get_disabled_projects_list # Populate disabled_projects_list global array
        current_disabled_projects_ref_name="disabled_projects_list" # Pass the name of the global array
    # else: service-specific .env loading will be handled per service later
    # and no disabled list is applied when a specific service is targeted.
    fi

    print_section "Service Discovery" "$CYAN"
    # Pass the name of the array containing disabled projects to discover_compose_files
    # This name is empty if service_filter is set and not "all" (meaning no exclusion based on the list for specific service)
    if [ -n "$service_filter" ] && [ "$service_filter" != "all" ]; then
        # Specific service is requested, do not pass the exclusion list name
        discover_compose_files "$service_filter" ""
    else
        # "all" services or no service_filter, pass the exclusion list name
        discover_compose_files "$service_filter" "$current_disabled_projects_ref_name"
    fi

    if ! print_discovered_files "Discovering Docker Compose files for startup..."; then
        # This means compose_files array is empty.
        # If a specific service was requested and not found, it's an error.
        if [ -n "$service_filter" ] && [ "$service_filter" != "all" ]; then
             print_error "No Docker Compose files found for specified service: $service_filter"
             return 1
        # If "all" services were requested (or no filter) and none were found (e.g., all disabled or none exist)
        elif [ -z "$service_filter" ] || [ "$service_filter" == "all" ]; then
             print_info "No services to start (either none defined, all are disabled, or filter criteria not met)."
             return 0 # Not an error in this case.
        fi
    fi

    # If compose_files is empty at this point (e.g. all services disabled), we should exit gracefully.
    if [ ${#compose_files[@]} -eq 0 ]; then
        print_info "No services to start after filtering."
        # Summary for 0 started, 0 failed
        local summary_lines_empty=()
        summary_lines_empty+=("${GREEN}Successfully started: 0 service(s)${NC}")
        print_summary "Startup Summary" "${summary_lines_empty[@]}"
        return 0
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

    print_header "OneStack Service Logs: ${service_target}" "$CYAN"
    print_info "Service: '${service_target}', Follow: '${follow_logs:-off}', Tail: '${tail_lines}', Additional Options: '${additional_opts[*]}'"

    if [ "$service_target" == "all" ]; then
        print_section "Environment Setup" "$BLUE"
        print_progress "Loading all environment files for combined logs..."
        load_all_env_files # Load all for combined view, individual services might have specifics but this is for general view

        print_section "Service Discovery" "$CYAN"
        discover_compose_files "all" "" # No exclude list for logs
        if ! print_discovered_files "Gathering logs for all services:"; then
            # If no services found, it's not necessarily an error for logs, just nothing to show.
            if [ ${#compose_files[@]} -eq 0 ]; then
                print_info "No services found to show logs for."
                return 0
            fi
            return 1 # Should not happen if print_discovered_files returns false but compose_files is not empty
        fi

        if [ ${#compose_files[@]} -eq 0 ]; then # Double check after print_discovered_files
            print_warning "No services found to show logs for"
            return 0
        fi

        local compose_cmd_args=()
        for f in "${compose_files[@]}"; do
            # For combined logs, we need to use the -p for each to avoid conflicts if service names are the same across files
            # However, 'docker compose logs' with multiple -f flags handles this by prefixing.
            # We just need to ensure each service's .env is loaded if its specific config affects logging (rare).
            # The global load_all_env_files should generally suffice here.
            compose_cmd_args+=("-f" "$f")
        done

        print_section "Log Output" "$MAGENTA"
        print_info "Showing combined logs (tail: $tail_lines${follow_logs:+, follow mode}). Press Ctrl+C to exit."
        # shellcheck disable=SC2086 # $follow_logs should not be quoted if empty
        docker compose ${compose_cmd_args[@]} logs --tail="$tail_lines" $follow_logs "${additional_opts[@]}"

    else
        # Specific service target
        print_section "Service Discovery" "$CYAN"
        find_service_compose_file "$service_name_for_logs"
        if [ -z "$found_compose_file" ]; then
            print_error "Service '$service_name_for_logs' not found"
            # Try to list available services
            discover_compose_files "all" "" # No exclude list for listing available
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
    discover_compose_files "$service_filter" "" # No exclude list for 'down'
    if ! print_discovered_files "Discovering Docker Compose files for shutdown..."; then
         # If a specific service was requested and not found, it's an error.
        if [ -n "$service_filter" ] && [ "$service_filter" != "all" ]; then
             print_error "No Docker Compose files found for specified service to shut down: $service_filter"
             return 1
        elif [ -z "$service_filter" ] || [ "$service_filter" == "all" ]; then
             print_info "Nothing to stop for: ${service_filter:-all services} (no services found/defined)."
             return 0 # Not an error if nothing found to stop
        fi
    fi

    # If compose_files is empty at this point (e.g. specific service not found), we should exit.
    if [ ${#compose_files[@]} -eq 0 ]; then
        # Message already printed by print_discovered_files or the logic above.
        # A summary indicating nothing was stopped.
        local summary_lines_empty=()
        summary_lines_empty+=("${GREEN}Successfully stopped: 0 service(s)${NC}")
        print_summary "Shutdown Summary" "${summary_lines_empty[@]}"
        return 0
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
    if [ $failed_services -gt 0 ]; then # Only show if there are failures
        summary_lines+=("${RED}Failed to stop: $failed_services service(s)${NC}")
        summary_lines+=("${YELLOW}Some services failed to stop. Check the logs above for details.${NC}")
        summary_lines+=("${GRAY}You may need to stop them manually (e.g. docker stop <container_id>)${NC}")
    fi
    
    print_summary "Shutdown Summary" "${summary_lines[@]}"

    if [ $failed_services -gt 0 ]; then
        return 1 # Indicate failure
    elif [ $successful_services -eq 0 ] && [ ${#compose_files[@]} -eq 0 ]; then
        # This means no services were targeted for shutdown (e.g. none defined or specific service not found)
        return 0 # Success, as there was nothing to do or target was not found.
    else
        print_success "All specified services have been stopped successfully!"
    fi
    return 0
}

action_status() {
    print_header "OneStack Service Status" "$CYAN"
    print_info "Status based on 'docker compose ps' output"

    # Discover all compose files. Status should generally reflect everything.
    # Pass "all" to discover_compose_files to get all services.
    # The original script had "false" for include_shared, but status should ideally show all.
    # Let's assume "all" is the desired behavior for a comprehensive status.
    print_section "Service Discovery" "$CYAN"
    discover_compose_files "all" "" # No exclude list for status

    if [ ${#compose_files[@]} -eq 0 ]; then
        print_error "No Docker Compose files found to check status!"
        return 1
    fi

    print_discovered_files "Checking status for the following services/configurations:"

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

action_ps() {
    local service_filter="$1" # Optional: specific service/group to show ps for
    print_header "OneStack Service PS: ${service_filter:-all services}" "$BLUE"

    # Discover services - always discover all or specific, do not use disable list for ps
    print_section "Service Discovery for PS" "$CYAN"
    discover_compose_files "$service_filter" "" # Empty exclude list

    if ! print_discovered_files "Discovering services to fetch 'ps' for..."; then
        if [ -n "$service_filter" ] && [ "$service_filter" != "all" ]; then
            print_error "No Docker Compose files found for specified service: $service_filter"
            return 1
        elif [ -z "$service_filter" ] || [ "$service_filter" == "all" ]; then
            print_info "No services found to fetch 'ps' for."
            return 0
        fi
    fi

    if [ ${#compose_files[@]} -eq 0 ]; then
        print_info "No services found to fetch 'ps' for after discovery."
        return 0
    fi

    print_section "Docker PS Output (Formatted)" "$MAGENTA"
    local first_service=true
    for file_path in "${compose_files[@]}"; do
        local service_name_from_path
        service_name_from_path=$(get_service_name "$file_path")

        # Load .env specific to this service context for 'docker compose ps'
        load_service_env_files "$service_name_from_path" "$file_path"

        if [ "$first_service" = true ]; then
            first_service=false
        else
            # Add a separator line between multiple services if listing all
            if [ -z "$service_filter" ] || [ "$service_filter" == "all" ]; then
                 echo -e "${BLUE}  ─────────────────────────────────────────────────────${NC}"
            fi
        fi
        print_subsection "Service: $service_name_from_path (Config: $file_path)" "$GREEN"

        # Using --all to show stopped containers as well.
        # Format: Name Image State Status Ports (simplified)
        local ps_output
        ps_output=$(docker compose -f "$file_path" -p "$service_name_from_path" ps --all --format "table {{.Name}}\t{{.Image}}\t{{.State}}\t{{.Status}}\t{{.Ports}}")

        if [ -z "$ps_output" ]; then
            print_warning "No services defined or running for this configuration ($service_name_from_path)"
            continue
        fi

        local header_processed=0
        # Use a more robust way to process lines, especially with sed
        echo -e "$ps_output" | while IFS= read -r line; do
            if [ $header_processed -eq 0 ]; then
                # For the header, replace "PORTS" with "PORTS (Host->Container)" for clarity
                line=$(echo "$line" | sed 's/PORTS/PORTS (Host->Container)/')
                echo -e "${BOLD}  $line${NC}" # Print header
                header_processed=1
                continue
            fi

            # Simplify ports: extract relevant parts like 80->80/tcp
            # This sed command aims to find patterns like 0.0.0.0:XXXX->YYYY/ ZZZ and simplify them.
            # It handles multiple port mappings separated by commas.
            # Example: "0.0.0.0:3000->3000/tcp, :::3000->3000/tcp" becomes "3000->3000/tcp"
            # Example: "0.0.0.0:5432->5432/tcp" becomes "5432->5432/tcp"
            # Example: "127.0.0.1:5432->5432/tcp" becomes "5432->5432/tcp" (if IP specific)
            # This can be tricky if ports are not published or format varies wildly.

            # Extract the ports column first, then process it.
            # Assuming tab-separated, ports is the 5th column (idx 4)
            local ports_raw
            ports_raw=$(echo -e "$line" | awk -F'\t' '{print $5}')
            local other_cols
            other_cols=$(echo -e "$line" | awk -F'\t' '{print $1"\t"$2"\t"$3"\t"$4}')

            local ports_simplified=""
            if [ -n "$ports_raw" ] && [ "$ports_raw" != "<no ports>" ]; then # Check if ports_raw is not empty and not placeholder
                # Process each comma-separated port mapping
                IFS=',' read -r -a port_array <<< "$ports_raw"
                local first_port_mapping=true
                for port_map in "${port_array[@]}"; do
                    # Remove IP and optional IPv6 brackets: e.g., "0.0.0.0:3000->3000/tcp" or "[::]:3000->3000/tcp"
                    # Also handles "127.0.0.1:..."
                    # Simplified: XXXX->YYYY/protocol
                    local simplified_map
                    simplified_map=$(echo "$port_map" | sed -E 's/^[0-9.:]+[:[]*([0-9]+->[0-9]+\/[a-zA-Z]+)[^,]*$/\1/' | sed -E 's/^:::([0-9]+->[0-9]+\/[a-zA-Z]+)[^,]*$/\1/')
                    # If it's just a container port (e.g. "3000/tcp"), keep as is after stripping potential noise
                    if ! echo "$simplified_map" | grep -q '->'; then
                        simplified_map=$(echo "$port_map" | sed -E 's/^[^0-9]*([0-9]+\/[a-zA-Z]+).*$/\1/')
                    fi

                    if [ "$first_port_mapping" = true ]; then
                        ports_simplified="$simplified_map"
                        first_port_mapping=false
                    else
                        ports_simplified="$ports_simplified, $simplified_map"
                    fi
                done
            else
                ports_simplified="" # Or keep as is if it was "<no ports>" or empty
            fi

            # Apply colors based on state (similar to action_status)
            local line_color="$NC"
            if [[ "$line" == *"unhealthy"* || "$line" == *"restarting"* ]]; then
                line_color="$RED"
            elif [[ "$line" == *"running"* || "$line" == *"Up"* ]]; then
                if [[ "$line" == *"starting"* ]]; then
                    line_color="$YELLOW"
                elif [[ "$line" == *"(healthy)"* ]]; then
                    line_color="$GREEN"
                elif [[ "$line" == *"(unhealthy)"* ]]; then
                    line_color="$RED"
                else
                    line_color="$GREEN"
                fi
            elif [[ "$line" == *"exited"* || "$line" == *"stopped"* || "$line" == *"created"* ]]; then
                line_color="$YELLOW"
            elif [[ "$line" == *"error"* || "$line" == *"dead"* ]]; then
                line_color="$RED"
            fi
            echo -e "${line_color}  ${other_cols}\t${ports_simplified}${NC}"
        done
    done
    return 0
}


action_restart() {
    local service_filter="$1" # Optional: specific service/group to restart
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
        stats)
            action_stats "$@"
            ;;
        ps)
            action_ps "$@"
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
            print_header "Service Discovery Test" "$CYAN"
            discover_compose_files "$1"
            print_discovered_files "Discovery results:"
            ;;
        _load_envs) # Example: bash bash/onestack.sh _load_envs traefik traefik/docker-compose.yml
            print_header "Environment Loading Test" "$BLUE"
            load_service_env_files "$1" "$2"
            ;;
        *)
            print_header "OneStack Usage" "$WHITE"
            echo -e "${BOLD}Usage:${NC} $0 {up|down|logs|status|stats|ps|restart|network|clean} [service_name/filter] [options...]"
            echo ""
            echo -e "${CYAN}${BOLD}Main Commands:${NC}"
            echo -e "  ${GREEN}up${NC}       - Start services"
            echo -e "  ${RED}down${NC}     - Stop services"
            echo -e "  ${YELLOW}logs${NC}     - Show service logs"
            echo -e "  ${BLUE}status${NC}   - Show service status"
            echo -e "  ${GREEN}stats${NC}    - Show Docker stats for services"
            echo -e "  ${BLUE}ps${NC}       - Show formatted 'docker ps' for services"
            echo -e "  ${MAGENTA}restart${NC}  - Restart services"
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
