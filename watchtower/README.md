# Watchtower - Automatic Docker Container Updates

## Overview

Watchtower is a process that monitors your running Docker containers and watches for changes to the images that those containers were originally started from. If Watchtower detects that an image has changed (e.g., a new version has been pushed to Docker Hub or another registry), it will automatically restart the container using the new image and the same options that were used when it was first deployed. This helps keep your applications up-to-date with the latest features and security patches.

## Requirements

- Docker (version recommended by your OS).
- Access to the Docker socket (`/var/run/docker.sock`) on the host.
- Internet connectivity for Watchtower to check for new images.

## Dependencies

- **Docker Engine:** Watchtower requires access to a running Docker engine's socket to monitor and restart containers.
- **Notification Services (Optional):** If notifications are configured (e.g., email, Slack, Gotify), Watchtower depends on network access to these services. The current configuration specifies `--notifications-hostname oracle2.madpin.dev` but doesn't show full notification setup in the compose file itself; this might be further configured via the `.env` file.

## Configuration

- Watchtower configuration is primarily managed through command-line arguments in `docker-compose.yml` and environment variables loaded from `watchtower/.env`.
- Create a `.env` file in the `watchtower` directory by copying from `watchtower/.env.template`. This file would typically contain notification service details if used (e.g., `WATCHTOWER_NOTIFICATIONS`, `WATCHTOWER_NOTIFICATION_URL`, etc.).
- **Key Command Line Arguments (in `docker-compose.yml`):**
    - `--schedule "0 0 5 * * *"`: Sets the schedule for Watchtower to check for updates. This is a cron expression meaning "at 05:00 AM every day".
    - `--notifications-hostname oracle2.madpin.dev`: Sets a custom hostname to be used in notifications. This helps identify which Watchtower instance sent the notification if you have multiple.
    - `--cleanup`: Removes old images after a successful update to save disk space.
    - `--remove-volumes`: **Caution!** This option removes anonymous volumes associated with the updated container. This is generally **not recommended** unless you are certain your containers do not use anonymous volumes for persistent data. Named volumes are not affected.
    - `--debug`: Enables debug logging for Watchtower, providing more verbose output.
- **Environment Variables:**
    - `TZ=Europe/Dublin`: Sets the timezone for the Watchtower container, which can be important for accurate scheduling and log timestamps.
    - Notification-related variables (e.g., `WATCHTOWER_NOTIFICATIONS`, `WATCHTOWER_NOTIFICATION_EMAIL_FROM`, etc.) would be defined in the `watchtower/.env` file as per Watchtower documentation if email or other notifications are desired.
- **Volume Mounts:**
    - `/var/run/docker.sock:/var/run/docker.sock`: Crucial for allowing Watchtower to interact with the Docker daemon.
    - `/etc/localtime:/etc/localtime:ro`: Mounts the host's time configuration for correct timezone handling.
- **Networking:**
    - Watchtower typically does not need to be on any specific Docker network unless it needs to reach a notification service that is only available on a particular internal network. By default, it doesn't join any user-defined networks in this compose file, meaning it will use Docker's default bridge network for internet access.

## Usage

1.  Ensure Docker is running.
2.  (Optional) Configure notification settings in `watchtower/.env` if you want to receive alerts about updates. Refer to the Watchtower documentation for available notification types and their specific environment variables.
3.  Start the Watchtower service:
    ```bash
    make up watchtower
    # Or directly:
    # docker-compose -f watchtower/docker-compose.yml up -d
    ```
4.  Watchtower will run in the background and check for updates according to the defined schedule.
5.  You can view Watchtower logs to see its activity:
    ```bash
    docker logs watchtower
    ```

## Which Containers Are Watched?

By default, Watchtower will monitor all containers that are running when it starts, and any new containers started while it is running. You can control which containers Watchtower monitors:

- **Watch All (Default):** No specific command arguments needed.
- **Monitor Specific Containers:** Pass the names of the containers to monitor as arguments at the end of the `command` (e.g., `mycontainer1 mycontainer2`).
- **Opt-out Specific Containers:** Add the label `com.centurylinklabs.watchtower.enable=false` to containers you do *not* want Watchtower to update.
- **Opt-in Specific Containers:** If you run Watchtower with the `--label-enable` flag (or `WATCHTOWER_LABEL_ENABLE=true` environment variable), it will *only* monitor containers that have the label `com.centurylinklabs.watchtower.enable=true`.

The current configuration does not specify container names or `--label-enable`, so it will attempt to watch all running containers.

## Troubleshooting

- **Containers Not Updating:**
    - Check Watchtower logs (`docker logs watchtower`) for errors or reasons why updates might not be occurring. Ensure debug mode (`--debug`) is enabled for more details.
    - Verify Watchtower has internet access to check image registries.
    - Ensure the image tags you are using are mutable (e.g., `latest`, or a version tag that gets updated). If you pin to a specific immutable image digest, Watchtower won't find a "new" image.
    - Check if the container was started from an image in a private registry; Watchtower might need credentials to access it (can be configured via environment variables or Docker config).
- **Incorrect Update Schedule:**
    - Double-check the cron expression in the `--schedule` argument.
    - Verify the `TZ` environment variable is set correctly if your schedule is timezone-dependent.
- **Data Loss After Update (if using `--remove-volumes`):**
    - **Immediately disable `--remove-volumes` if you suspect data loss.** This option is dangerous if your containers rely on anonymous volumes for data. Use named volumes for all persistent data, as they are not affected by this flag.

## Security Notes

- **Docker Socket Access:** Watchtower requires access to the Docker socket, which is a privileged operation. Ensure you are using the official `containrrr/watchtower` image or one from a trusted source.
- **`--remove-volumes`:** Use this flag with extreme caution. It can lead to data loss if containers use anonymous volumes for important data. It's safer to manage volume cleanup manually or use named volumes.
- **Automatic Updates:** While convenient, automatic updates can sometimes introduce breaking changes if a new image version has them. Monitor your applications after updates, or consider strategies like pinning to major/minor versions and only automatically updating patch versions if your image tagging scheme supports it. You can also use Watchtower to only notify you of updates without automatically applying them (`--monitor-only` flag).
- Regularly check Watchtower logs to be aware of what updates are happening.

## Additional Resources
- [Watchtower Official Website (GitHub)](https://containrrr.dev/watchtower/)
- [Watchtower Documentation](https://containrrr.dev/watchtower/arguments/) (for command-line arguments)
- [Watchtower Notification Configuration](https://containrrr.dev/watchtower/notifications/)
