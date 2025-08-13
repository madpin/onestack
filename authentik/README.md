# Authentik - Identity Provider

Authentik is an open-source Identity Provider focused on flexibility and versatility. This setup integrates Authentik with the OneStack shared services.

## Configuration

### Required Environment Variables

The following variables must be set in `.env`:

- `AUTHENTIK_SECRET_KEY`: Secret key for Authentik (already generated)
- `POSTGRES_AUTHENTIK_DB`: Database name for Authentik (set to 'authentik')

### Optional Configuration

You can customize the following in `.env`:

- `AUTHENTIK_TAG`: Authentik version tag (defaults to 2025.6.4)
- `AUTHENTIK_EMAIL_FROM`: Email address for outgoing emails (defaults to authentik@${BASE_DOMAIN})
- Email SMTP settings (uses OneStack's Brevo configuration by default)

## Services

This configuration runs two containers:

1. **authentik-server**: Main Authentik web server
2. **authentik-worker**: Background worker for tasks

## Integration with OneStack

- **Database**: Uses shared PostgreSQL service with dedicated 'authentik' database
- **Cache**: Uses shared Redis service
- **Email**: Uses OneStack's Brevo SMTP configuration
- **Networking**: Connected to both `web` and `internal_network` networks
- **Reverse Proxy**: Configured for Traefik with automatic HTTPS

## Initial Setup

1. Ensure shared PostgreSQL and Redis services are running
2. Start Authentik services: `docker compose up -d`
3. Navigate to `https://authentik.${BASE_DOMAIN}/if/flow/initial-setup/`
4. Set up the initial admin user (akadmin)

## Access

- **Web Interface**: `https://authentik.${BASE_DOMAIN}`
- **Admin Interface**: `https://authentik.${BASE_DOMAIN}/if/admin/`

## Docker Socket Integration

The worker container has access to the Docker socket for:

- Docker integration features
- Outpost management
- Container discovery

## Security Notes

- The worker runs as root to manage Docker socket permissions
- Secret key is generated with high entropy (60 bytes base64)
- All external communication is via HTTPS through Traefik
- Database and Redis connections are internal network only

## Volumes

- `./data/media`: Media files (logos, icons, etc.)
- `./data/certs`: Certificates for outposts
- `./data/custom-templates`: Custom email/web templates
- `/var/run/docker.sock`: Docker socket (worker only)

## Official Documentation

For more information, visit: [Authentik Documentation](https://docs.goauthentik.io/)
