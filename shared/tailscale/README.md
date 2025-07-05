# Tailscale Shared Service

This shared service provides Tailscale connectivity for the OneStack infrastructure.

## Setup

1. **Get a Tailscale Auth Key**:
   - Go to https://login.tailscale.com/admin/settings/keys
   - Create a new auth key (consider using a reusable key for containers)
   - Copy the auth key

2. **Configure Environment**:
   ```bash
   # Edit the .env file
   nano /home/madpin/onestack/shared/tailscale/.env
   ```
   
   Replace `TS_AUTHKEY=tskey-auth-your-auth-key-here` with your actual auth key.

3. **Start the Service**:
   ```bash
   # From the OneStack root directory
   make up
   ```

## Network Configuration

The Tailscale service creates a `tailscale_network` that other services can join to access Tailscale connectivity.

### Adding Services to Tailscale Network

To connect any service to Tailscale, add the network to their docker-compose.yml:

```yaml
services:
  your-service:
    # ...existing configuration...
    networks:
      - web                    # existing networks
      - tailscale_network     # add this line

networks:
  web:
    external: true
  tailscale_network:         # add this network
    external: true
    name: ${TAILSCALE_NETWORK_NAME}
```

## Features

- **Subnet Router**: The configuration includes `--accept-routes` to allow accessing remote subnets
- **Tagging**: Services are tagged with `tag:onestack` for organization
- **Health Checks**: Built-in health checking using `tailscale status`
- **Persistent State**: Tailscale state is stored in `./data/` for persistence

## Usage

Once running, the Tailscale service will:
- Connect to your Tailscale network
- Provide connectivity to other containers in the `tailscale_network`
- Allow access to your containers from other devices on your Tailscale network

## Troubleshooting

1. **Check container logs**:
   ```bash
   docker logs tailscale
   ```

2. **Verify Tailscale status**:
   ```bash
   docker exec tailscale tailscale status
   ```

3. **Check network connectivity**:
   ```bash
   docker exec tailscale tailscale ip
   ```

## Security Notes

- The auth key is sensitive - keep it secure
- Consider using ephemeral keys for testing
- Review Tailscale ACLs to control access appropriately
- The container runs with `NET_ADMIN` capabilities as required by Tailscale
