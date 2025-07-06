# Shared Tailscale Service

## Overview

This service provides Tailscale connectivity to the Docker environment and potentially other services within the stack. Tailscale creates a secure, private network (a "tailnet") between your devices, servers, and cloud instances, making them accessible as if they were on the same local network, regardless of their physical location. This service acts as a Tailscale client within Docker.

## Requirements

- Docker (version recommended by your OS).
- A Tailscale account.
- A Tailscale authentication key (`TS_AUTHKEY`).
- The `tailscale_network` Docker network must be created (or another network intended for Tailscale connectivity).
- The host system must have the `/dev/net/tun` device available and accessible to the container.
- The container requires `NET_ADMIN` and `SYS_MODULE` capabilities.

## Dependencies

This service connects to the Tailscale control plane (external) but typically doesn't have local service dependencies to run itself. Other services can depend on it by joining its Docker network.

## Configuration

- Create a `.env` file in the `shared/tailscale/` directory by copying from `shared/tailscale/.env.template`.
    ```bash
    cp shared/tailscale/.env.template shared/tailscale/.env
    ```
- **Key Environment Variables (in `shared/tailscale/.env` or root `.env` if sourced globally):**
    - `TS_AUTHKEY`: **Critical.** Your Tailscale authentication key. Obtain this from the Tailscale admin console (Keys section). Consider using a reusable or ephemeral key depending on your needs.
    - `TS_EXTRA_ARGS`: Additional arguments for the `tailscale up` command.
        - `--advertise-tags=tag:onestack`: Advertises this node with the tag `tag:onestack` in your Tailscale network. Useful for ACLs and organization.
        - `--accept-routes`: Allows this node to accept routes advertised by other nodes in your tailnet (e.g., for accessing remote subnets).
    - `TS_STATE_DIR`: Path within the container where Tailscale stores its state (default `/var/lib/tailscale`).
    - `TS_USERSPACE`: Set to `false` to run Tailscale in kernel mode (requires `/dev/net/tun` and capabilities).
    - `TS_ENABLE_HEALTH_CHECK`: Enables Tailscale's built-in health checking features (though the Docker healthcheck uses `tailscale status`).
    - `TS_HOSTNAME`: Hostname to advertise to the Tailscale network (e.g., `OneStack`).
- The root `.env` file should also define `TAILSCALE_NETWORK_NAME`.
- **Volume Mounts:**
    - `./data:/var/lib/tailscale`: Persists Tailscale state across container restarts. This is important so the node doesn't have to re-authenticate and get a new IP on every start.
    - `/dev/net/tun:/dev/net/tun`: Provides the TUN device necessary for Tailscale's kernel mode networking.
- **Networking:**
    - The service itself joins the `tailscale_network`.
    - Other services that need to be part of this Tailscale node's network access can also join the `tailscale_network`.
- **Capabilities:**
    - `NET_ADMIN` and `SYS_MODULE` are required for Tailscale to manipulate network interfaces and load necessary kernel modules.

## Usage

1.  Ensure Docker is running and the host system meets the requirements (especially `/dev/net/tun`).
2.  Obtain a `TS_AUTHKEY` from your Tailscale admin console.
3.  Set the `TS_AUTHKEY` and other `TS_*` variables in the relevant `.env` file.
4.  Start the Tailscale service:
    ```bash
    make up shared-tailscale
    # Or directly:
    # docker-compose -f shared/tailscale/docker-compose.yml up -d
    ```
5.  Once running, the container will:
    - Authenticate to your Tailscale account using the auth key.
    - Connect to your tailnet.
    - Become accessible via its Tailscale IP address from other devices in your tailnet.
    - Other containers on the same `tailscale_network` in Docker might be able to leverage this connectivity (depending on how routing is configured and if this container acts as an exit node or subnet router for them, which is not its primary config here but possible with more `TS_EXTRA_ARGS`).
6.  To allow other Docker services to communicate over Tailscale through this client, add them to the `tailscale_network`:
    ```yaml
    # In another service's docker-compose.yml
    services:
      your-other-service:
        # ...
        networks:
          - some_other_network
          - tailscale_network # Add this

    networks:
      some_other_network:
        # ...
      tailscale_network:
        external: true
        name: ${TAILSCALE_NETWORK_NAME} # Ensure this matches the network Tailscale uses
    ```

## Troubleshooting

- **Container fails to start or connect:**
    - Check container logs: `docker logs tailscale`. Look for authentication errors or issues with `/dev/net/tun`.
    - Ensure `TS_AUTHKEY` is correct and valid.
    - Verify `/dev/net/tun` exists and is accessible.
    - Confirm `NET_ADMIN` and `SYS_MODULE` capabilities are granted.
- **Cannot connect to other Tailscale nodes / "No IP address":**
    - Verify Tailscale status within the container: `docker exec tailscale tailscale status`. It should show "Running" or similar.
    - Check Tailscale IP: `docker exec tailscale tailscale ip -4` (for IPv4).
    - Ensure your Tailscale ACLs allow communication between this node and others.
- **`--accept-routes` not working:**
    - Ensure the routes are being advertised correctly by another node in your tailnet (e.g., a subnet router or exit node).
    - Check `docker exec tailscale tailscale netcheck` for any NAT issues that might affect connectivity.

## Security Notes

- **`TS_AUTHKEY` is highly sensitive.** Protect it like a password. Consider using ephemeral keys if the node doesn't need to persist its identity long-term.
- **Capabilities:** Granting `NET_ADMIN` and `SYS_MODULE` provides significant privileges to the container. Only use the official `tailscale/tailscale` image or images from trusted sources.
- **Tailscale ACLs:** Use Tailscale Access Control Lists (ACLs) in your Tailscale admin console to define which devices can connect to each other and what ports/protocols are allowed. This is crucial for network segmentation and security within your tailnet.
- Regularly update the Tailscale image (`tailscale/tailscale:latest`) for the latest features and security updates.

## Additional Resources
- [Tailscale Official Website](https://tailscale.com/)
- [Tailscale Documentation](https://tailscale.com/kb/)
- [Tailscale Docker Documentation](https://tailscale.com/kb/1132/docker/)
- [Tailscale Auth Keys](https://tailscale.com/kb/1085/auth-keys/)
