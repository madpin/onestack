# RcloneBackup Service

This service provides automated backup functionality for OneStack, backing up files and PostgreSQL databases to cloud storage using rclone.

## Configuration

The service is configured with three separate backup containers using DRY principles:

### � **rclonebkp-folders** (Files Only)

- **Paperless Media**: `/home/madpin/onestack/paperless/data/media` → `/backup/paperless_media`
- **Calibre Library**: `/home/madpin/calibre_library` → `/backup/calibre_library`
- **Schedule**: Every 3 hours at minute 0 (e.g., 00:00, 03:00, 06:00...)

### 🗄️ **rclonebkp-db-paperless** (Database Only)

- **Paperless Database**: `paperless` PostgreSQL database
- **Schedule**: Every 3 hours at minute 10 (e.g., 00:10, 03:10, 06:10...)

### 🗄️ **rclonebkp-db-litellm** (Database Only)

- **LiteLLM Database**: `litellm` PostgreSQL database
- **Schedule**: Every 3 hours at minute 20 (e.g., 00:20, 03:20, 06:20...)

## Architecture

The configuration uses **YAML anchors and aliases** to implement DRY principles:

- **Base service** (`rclonebkp-base`): Contains common configuration
- **Shared environment** (`rclone-env`): Common environment variables
- **Individual services**: Inherit from base and add specific configuration

## Schedule

All services run every 3 hours but are offset by 10 minutes each to avoid conflicts and resource contention.

## Cloud Storage

- **Remote**: `pcloud` (configure this in rclone first)
- **Destination**: `/backup_onestack/` folder in your pcloud storage

## Email Notifications

The service sends email notifications for:
- ✅ Successful backups
- ❌ Failed backups

Configure your email settings in the `.env` file.

## Setup Instructions

### 1. Configure Rclone Remote

Before starting the service, you need to configure the rclone remote named "pcloud":

```bash
# Create the rclone config and configure the remote
docker run --rm -it \
  --mount type=bind,source="$(pwd)/config",target=/config/ \
  madpin/rclone-backup:latest \
  rclone config
```

Follow the prompts to configure your pcloud remote. **Important**: Name it exactly `pcloud` or update the `RCLONE_REMOTE_NAME` variable in `.env`.

### 2. Verify Configuration

Check that your rclone configuration is correct:

```bash
docker run --rm -it \
  --mount type=bind,source="$(pwd)/config",target=/config/ \
  madpin/rclone-backup:latest \
  rclone config show
```

### 3. Start the Service

Start the backup services:

```bash
# From the shared/rclonebkp directory
docker-compose up -d

# Or from the root directory
make up rclonebkp
```

### 4. Test Email Notifications

Test that email notifications work:

```bash
docker run --rm -it \
  --env-file .env \
  madpin/rclone-backup:latest \
  mail success
```

## Manual Backup

Trigger a manual backup:

```bash
# From the shared/rclonebkp directory
docker-compose exec rclonebkp-folders /app/scripts/backup.sh
docker-compose exec rclonebkp-db-paperless /app/scripts/backup.sh
docker-compose exec rclonebkp-db-litellm /app/scripts/backup.sh

# Or trigger from outside the container (example for folders)
docker run --rm -it \
  --env-file .env \
  --mount type=bind,source="$(pwd)/config",target=/config/ \
  -v /home/madpin/onestack/paperless/data/media:/backup/paperless_media:ro \
  -v /home/madpin/calibre_library:/backup/calibre_library:ro \
  --network onestack_internal_network \
  madpin/rclone-backup:latest \
  /app/scripts/backup.sh
```

## Monitoring

### View Logs

```bash
# Follow backup logs
docker-compose logs -f rclonebkp-folders
docker-compose logs -f rclonebkp-db-paperless
docker-compose logs -f rclonebkp-db-litellm

# Or using make
make logs rclonebkp
```

### Check Status

```bash
# Check service status
docker-compose ps

# Check health
docker-compose exec rclonebkp ps aux
```

## Configuration Variables

All configuration is done through environment variables in the `.env` file:

| Variable | Description | Default |
|----------|-------------|---------|
| `RCLONE_CRON` | Backup schedule (cron format) | `0 */3 * * *` |
| `RCLONE_REMOTE_NAME` | Rclone remote name | `pcloud` |
| `RCLONE_REMOTE_DIR` | Destination directory | `/backup_onestack/` |
| `RCLONE_BACKUP_KEEP_DAYS` | Days to keep backups | `7` |
| `RCLONE_MAIL_TO` | Email recipient | `madpin@gmail.com` |
| `RCLONE_ZIP_PASSWORD` | Archive password | `123456` |

## File Structure

```
shared/rclonebkp/
├── docker-compose.yml    # Service definition
├── .env                  # Configuration variables
└── README.md            # This file
```

## Troubleshooting

### Common Issues

1. **Rclone remote not configured**: Make sure to run `rclone config` first
2. **Email notifications not working**: Check SMTP settings in `.env`
3. **PostgreSQL connection failed**: Verify database is running and accessible
4. **Permission denied**: Check that source directories exist and are readable

### Debug Mode

Enable debug logging:

```bash
# Add to .env
RCLONE_GLOBAL_FLAG=-v

# Restart service
docker-compose restart rclonebkp
```

### Check Backup Files

List files in cloud storage:

```bash
docker run --rm -it \
  --mount type=bind,source="$(pwd)/config",target=/config/ \
  madpin/rclone-backup:latest \
  rclone ls pcloud:/backup_onestack/
```
