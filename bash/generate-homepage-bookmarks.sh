#!/bin/bash
#
# This script updates homepage/config/bookmarks.yaml by adding new Traefik-exposed services under the 'Services' group.
# - It scans all docker-compose.yml files for traefik router host rules.
# - It parses the existing bookmarks.yaml and collects all service names anywhere in the file.
# - It only appends new services (not already present anywhere) to the 'Services' group.
# - All other groups and bookmarks are left untouched.
# - The script is safe to run repeatedly and will not duplicate entries.
#
# Usage: bash/generate-homepage-bookmarks.sh

set -e

ROOTDIR="$(dirname "$0")/.."  # Root directory of the project
BOOKMARKS_FILE="$ROOTDIR/homepage/config/bookmarks.yaml"  # Path to bookmarks.yaml
ENV_FILE="$ROOTDIR/.env"  # Path to root .env file
TMP_FILE="$BOOKMARKS_FILE.tmp"  # Temporary file for atomic update

# Get BASE_DOMAIN from .env (strip comments and whitespace)
BASE_DOMAIN=$(grep '^BASE_DOMAIN=' "$ENV_FILE" | head -n1 | cut -d'=' -f2 | cut -d'#' -f1 | tr -d ' ')

# Find all traefik router host rules in all docker-compose.yml files
mapfile -t HOST_RULES < <(grep -r --include='docker-compose.yml' 'traefik.http.routers.' "$ROOTDIR" | grep 'rule=Host(')

# --- Parse all existing service names anywhere in bookmarks.yaml ---
all_existing_services=()  # Array to hold all service names found anywhere
while IFS= read -r line; do
    # Match lines like '    - ServiceName:'
    if [[ $line =~ ^[[:space:]]+-[[:space:]]([A-Za-z0-9_-]+): ]]; then
        svc=$(echo "$line" | sed -n 's/^[[:space:]]*- \([A-Za-z0-9_-]*\):.*/\1/p')
        all_existing_services+=("$svc")
    fi
done < "$BOOKMARKS_FILE"

# --- Prepare new services to add ---
new_entries=()  # Array to hold new YAML entries
for rule in "${HOST_RULES[@]}"; do
    # Extract service name from traefik label
    SERVICE=$(echo "$rule" | sed -n 's/.*routers\.\([^\.]*\)\.rule=.*/\1/p')
    # Extract host from traefik label
    HOST=$(echo "$rule" | sed -n 's/.*Host(`\(.*\)`).*/\1/p')
    # Replace ${BASE_DOMAIN} and $BASE_DOMAIN with actual value
    HOST_REAL=$(echo "$HOST" | sed -E "s/\\$\{BASE_DOMAIN\}|\\$BASE_DOMAIN/$BASE_DOMAIN/g")
    # Skip if host is empty or contains whitespace
    if [[ -z "$HOST_REAL" || "$HOST_REAL" =~ [[:space:]] ]]; then
        echo "[WARN] Skipping $SERVICE: invalid or empty host ($HOST_REAL)" >&2
        continue
    fi
    # Abbreviation: first 2 letters, uppercase
    ABBR=$(echo "$SERVICE" | cut -c1-2 | tr '[:lower:]' '[:upper:]')
    # Only add if not already present anywhere in bookmarks.yaml
    found=0
    for exist in "${all_existing_services[@]}"; do
        if [[ "$exist" == "$(tr '[:lower:]' '[:upper:]' <<< ${SERVICE:0:1})${SERVICE:1}" ]]; then
            found=1
            break
        fi
    done
    if [[ $found -eq 0 ]]; then
        # Format as homepage-compatible YAML
        new_entries+=("    - $(tr '[:lower:]' '[:upper:]' <<< ${SERVICE:0:1})${SERVICE:1}:\n        - abbr: $ABBR\n          href: https://$HOST_REAL")
    fi
done

# --- Rebuild bookmarks.yaml ---
# Copy everything up to and including '- Services:', then all existing services, then new ones, then the rest
in_services=0  # Flag: are we inside Services group?
services_written=0  # Flag: did we already write new entries?
{
    while IFS= read -r line; do
        # Detect start of Services group
        if [[ $line =~ ^-\ Services: ]]; then
            in_services=1
            echo "$line"
            continue
        fi
        # If inside Services group
        if [[ $in_services -eq 1 ]]; then
            # If a new group starts, finish Services group
            if [[ $line =~ ^-\  ]]; then
                in_services=0
                services_written=1
                # Write new entries if any
                for entry in "${new_entries[@]}"; do
                    echo -e "$entry"
                done
                echo "$line"
                continue
            fi
        fi
        # Output all other lines as-is
        echo "$line"
    done < "$BOOKMARKS_FILE"
    # If file ended and we were still in services, append new entries
    if [[ $in_services -eq 1 && $services_written -eq 0 ]]; then
        for entry in "${new_entries[@]}"; do
            echo -e "$entry"
        done
    fi
} > "$TMP_FILE"

# Atomically replace the original file
mv "$TMP_FILE" "$BOOKMARKS_FILE"
echo "Bookmarks updated at $BOOKMARKS_FILE"
