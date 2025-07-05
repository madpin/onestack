#!/bin/bash

# Tailscale management script for OneStack
# Usage: bash/tailscale.sh [status|ip|devices|logs]

set -e

# Navigate to the project root
cd "$(dirname "$0")/.."

# Source environment
source ./bash/env.sh
load_all_env_files

TAILSCALE_CONTAINER="tailscale"

case "${1:-status}" in
    "status")
        echo "=== Tailscale Status ==="
        docker exec "$TAILSCALE_CONTAINER" tailscale status
        ;;
    "ip")
        echo "=== Tailscale IP ==="
        docker exec "$TAILSCALE_CONTAINER" tailscale ip
        ;;
    "devices")
        echo "=== Tailscale Devices ==="
        docker exec "$TAILSCALE_CONTAINER" tailscale status --json | jq '.Peer[] | {Name: .HostName, IP: .TailscaleIPs[0], Online: .Online}'
        ;;
    "logs")
        echo "=== Tailscale Container Logs ==="
        docker logs "$TAILSCALE_CONTAINER" "${@:2}"
        ;;
    "ping")
        if [ -z "$2" ]; then
            echo "Usage: bash/tailscale.sh ping <device-name-or-ip>"
            exit 1
        fi
        echo "=== Ping $2 via Tailscale ==="
        docker exec "$TAILSCALE_CONTAINER" ping -c 4 "$2"
        ;;
    "restart")
        echo "=== Restarting Tailscale ==="
        docker restart "$TAILSCALE_CONTAINER"
        ;;
    *)
        echo "Usage: bash/tailscale.sh [status|ip|devices|logs|ping|restart]"
        echo ""
        echo "Commands:"
        echo "  status    - Show Tailscale connection status"
        echo "  ip        - Show Tailscale IP addresses"
        echo "  devices   - Show connected devices (requires jq)"
        echo "  logs      - Show container logs"
        echo "  ping      - Ping a device via Tailscale"
        echo "  restart   - Restart the Tailscale container"
        ;;
esac
