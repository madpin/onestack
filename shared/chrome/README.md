# Shared Headless Chrome Service

## Overview

This service provides a headless instance of Google Chrome (Chromium) running in a Docker container. It is intended to be used by other applications within the stack that require browser automation, web scraping, PDF generation from web pages, or other tasks that necessitate a headless browser environment. It listens for remote debugging connections.

## Requirements

- Docker (version recommended by your OS, typically a recent version).
- The `internal_network` Docker network must be created (usually handled by a global `Makefile` or setup script).

## Dependencies

This service typically has no external service dependencies to run itself, but other services depend on it.
- **Dependent Services (Examples):** Services like `karakeep` or custom applications that perform web scraping or page rendering might depend on this headless Chrome instance.

## Configuration

- This service does not use an `.env.template` or a dedicated `.env` file in its directory (`shared/chrome/`) as its configuration is minimal and set directly in the `docker-compose.yml`.
- The root `.env` file (or global environment) should define `INTERNAL_NETWORK_NAME`.
- **Command Line Arguments:** The `docker-compose.yml` specifies the command to run Chromium with the following important flags:
    - `--headless`: Runs Chrome in headless mode (no GUI).
    - `--disable-gpu`: Disables GPU hardware acceleration (often necessary in containers).
    - `--no-sandbox`: Disables the Chrome sandbox. This is often required for Chrome to run correctly in Docker, especially when running as root, but be aware of the security implications (see Security Notes).
    - `--remote-debugging-address=0.0.0.0`: Allows remote debugging connections from any IP address that can reach the container (within the Docker network).
    - `--remote-debugging-port=9222`: Specifies the port for remote debugging connections.
- **Networking:**
    - The service is attached to the `internal_network`, making it accessible to other services on the same network.
    - It does **not** expose any ports to the host or through Traefik by default, as it's intended for internal use by other services. Services connect to it using its service name (`chrome`) and port `9222` on the internal Docker network (e.g., `ws://chrome:9222`).

## Usage

1.  Ensure Docker is running.
2.  Ensure the `INTERNAL_NETWORK_NAME` environment variable is set correctly in your global environment.
3.  Start the headless Chrome service. This is typically done as a dependency of another service or as part of a general "up" command for shared services.
    ```bash
    # Usually started as a dependency. To start it directly (e.g., for testing):
    # docker-compose -f shared/chrome/docker-compose.yml up -d
    # Or if part of a larger shared services Makefile target:
    make up chrome
    ```
4.  Other services can then connect to this headless Chrome instance using a WebDriver client (like Puppeteer, Selenium, Playwright) pointed to `ws://chrome:9222`. The exact connection URL might vary based on the client library (e.g. `http://chrome:9222` for some DevTools protocol interactions).

## Troubleshooting

- **Service not starting/crashing:**
    - Check container logs: `docker logs chrome` (or the actual container name if different).
    - The `--no-sandbox` flag is often key. If removed, Chrome might fail to start in some Docker environments.
    - Ensure the base image `zenika/alpine-chrome` is pulled correctly.
- **Other services cannot connect:**
    - Verify the dependent service is on the same `internal_network` as the `chrome` service.
    - Ensure the dependent service is using the correct address: `chrome:9222`.
    - Check for any firewall rules within Docker or on the host that might prevent communication (less common for internal Docker networks).
- **Performance issues/high resource usage:**
    - Headless Chrome can be resource-intensive. Monitor CPU and memory usage.
    - Ensure your applications are closing browser tabs/pages and disconnecting properly to free up resources.

## Security Notes

- **`--no-sandbox` Flag:** Running Chrome with `--no-sandbox` significantly reduces its security. This flag is often necessary for Chrome to function correctly inside Docker containers, especially when the container user is root. Only use this configuration in trusted environments where the content being processed by Chrome is also trusted. Avoid using it if processing untrusted web content directly from the internet without other security measures.
- **Network Exposure:** This service is intentionally not exposed publicly via Traefik or host ports. It should only be accessible on the internal Docker network by other trusted services.
- **Resource Management:** Be mindful that applications using this headless Chrome instance can consume significant system resources (CPU, memory). Implement proper error handling and resource cleanup in your client applications.

## Additional Resources
- [Puppeteer Documentation (Node.js library for Chrome DevTools Protocol)](https://pptr.dev/)
- [Selenium WebDriver Documentation](https://www.selenium.dev/documentation/webdriver/)
- [Playwright Documentation](https://playwright.dev/docs/intro)
