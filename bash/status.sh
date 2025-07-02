#!/bin/bash

# Status Script
# Shows the status of all Docker Compose services with improved presentation

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color

# Navigate to the project root
cd "$(dirname "$0")/.."

source ./bash/env.sh

printf "${CYAN}=== OneStack Service Status ===${NC}\n"
printf "${BLUE}Legend: [Up: ${GREEN}running${NC}${BLUE}] [Exited: ${YELLOW}stopped${NC}${BLUE}] [Unhealthy/Error: ${RED}unhealthy/error${NC}${BLUE}]${NC}\n\n"

# Auto-discover Docker Compose files
discover_compose_files "" "false"  # Don't include shared directories for status check

if [ ${#compose_files[@]} -eq 0 ]; then
    printf "${RED}No Docker Compose files found!${NC}\n"
    exit 1
fi

# Show status for each service
for compose_file in "${compose_files[@]}"; do
    service_name=$(get_service_name "$compose_file")
    printf "${YELLOW}\n==============================\n${NC}"
    printf "${GREEN}Service: $service_name${NC} (${CYAN}$compose_file${NC})\n"
    printf "${BLUE}--------------------------------${NC}\n"
    # Get status output
    status_output=$(docker compose -f "$compose_file" ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}")
    # Colorize status lines
    while IFS= read -r line; do
        if [[ "$line" == *"STATE"* ]]; then
            printf "%s\n" "$line"
        elif [[ "$line" == *"unhealthy"* ]]; then
            printf "${RED}%s${NC}\n" "$line"
        elif [[ "$line" == *"running"* ]]; then
            printf "${GREEN}%s${NC}\n" "$line"
        elif [[ "$line" == *"exited"* ]]; then
            printf "${YELLOW}%s${NC}\n" "$line"
        elif [[ "$line" == *"error"* || "$line" == *"dead"* ]]; then
            printf "${RED}%s${NC}\n" "$line"
        else
            printf "%s\n" "$line"
        fi
    done <<< "$status_output"
done

printf "${CYAN}\n=== End of Status ===${NC}\n"
