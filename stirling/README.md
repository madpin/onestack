# Stirling PDF

## Overview

Stirling PDF is a locally hosted, web-based PDF manipulation tool. It allows you to perform various operations on PDF documents, such as merging, splitting, converting, rotating, compressing, adding watermarks, OCR, and much more. This service provides a self-contained PDF toolkit accessible via a web browser.

## Requirements

- Docker (version recommended by your OS, typically compatible with `stirlingtools/stirling-pdf:latest`).
- The `web` and `internal_network` Docker networks must be created.
- Traefik service running and configured for exposing web services.
- Initial login credentials must be defined if security is enabled.

## Dependencies

- **Traefik:** Used as a reverse proxy to expose Stirling PDF securely with SSL.

## Configuration

- Create a `.env` file in the `stirling` directory by copying from `stirling/.env.template`, or ensure variables are set in the root `.env` file.
- **Key Environment Variables (expected in `stirling/.env` or root `.env`):**
    - `STIRLING_USERNAME`: The username for the initial administrator account if `SECURITY_ENABLELOGIN=true`.
    - `STIRLING_PASSWORD`: The password for the initial administrator account. **Set a strong password.**
    - `BASE_DOMAIN`: Used for Traefik routing.
- **Other Environment Variables for Stirling PDF:**
    - `DOCKER_ENABLE_SECURITY=true`: Enables security features. Recommended.
    - `LANGS=en_GB`: Sets the default OCR languages. You can add more (e.g., `en_GB+fra+deu`). Ensure corresponding `tessdata` files are present in `./data/trainingData`.
    - `SECURITY_ENABLELOGIN=true`: Enables the login system.
    - `SECURITY_INITIALLOGIN_USERNAME=${STIRLING_USERNAME}`: Sets the initial admin username.
    - `SECURITY_INITIALLOGIN_PASSWORD=${STIRLING_PASSWORD}`: Sets the initial admin password.
    - `UI_APPNAME`, `UI_HOMEDESCRIPTION`, `UI_APPNAVBARNAME`: Optional variables for UI customization.
- The root `.env` file should also define `WEB_NETWORK_NAME` and `INTERNAL_NETWORK_NAME`.
- **Volume Mounts:**
    - `./data/trainingData:/usr/share/tessdata`: Mounts Tesseract OCR language data. Download additional language files (e.g., `fra.traineddata`, `deu.traineddata`) into `stirling/data/trainingData/` on the host to enable more OCR languages specified in `LANGS`.
    - `./config/extraConfigs:/configs`: For custom configuration files used by Stirling PDF.
    - `./config/customFiles:/customFiles/`: For custom files like fonts or watermarks.
    - `./data/logs:/logs/`: Stores Stirling PDF application logs.
    - `./data/pipeline:/pipeline/`: Used for pipeline processing or temporary file storage by Stirling PDF.
- **Networking:**
    - Attached to `web` (for Traefik exposure) and `internal_network`.
    - Traefik exposes Stirling PDF at `stirling.${BASE_DOMAIN}` on port `8080` internally.

## Usage

1.  Ensure Docker is running.
2.  Define `STIRLING_USERNAME`, `STIRLING_PASSWORD`, and `BASE_DOMAIN` in your relevant `.env` file.
3.  If using OCR for languages other than English, download the respective `.traineddata` files from the Tesseract GitHub repository (e.g., `tessdata_fast` or `tessdata_best`) and place them in `stirling/data/trainingData/` on the host. Update the `LANGS` environment variable accordingly.
4.  Start the Stirling PDF service:
    ```bash
    make up stirling
    # Or directly:
    # docker-compose -f stirling/docker-compose.yml up -d
    ```
5.  Access Stirling PDF in your web browser at: `https://stirling.${BASE_DOMAIN}`.
6.  If `SECURITY_ENABLELOGIN=true`, log in with the `STIRLING_USERNAME` and `STIRLING_PASSWORD`.

## Troubleshooting

- **Login Issues:**
    - Ensure `SECURITY_ENABLELOGIN=true` is set.
    - Verify `STIRLING_USERNAME` and `STIRLING_PASSWORD` are correctly set in the environment variables and that you are using these credentials.
    - Check Stirling PDF logs for authentication errors: `docker logs stirling`.
- **OCR Not Working or Missing Languages:**
    - Confirm the `LANGS` environment variable includes the desired language codes.
    - Ensure the corresponding `.traineddata` files are present in the host directory mounted to `/usr/share/tessdata` (i.e., `stirling/data/trainingData/`).
    - Check logs for Tesseract-related errors.
- **File Upload/Processing Errors:**
    - Check Stirling PDF logs for specific error messages.
    - Ensure sufficient disk space and container resources.
    - Verify permissions on the mounted volumes (`./data/pipeline`, etc.) if issues persist.
- **Traefik Issues:** If not accessible via `https://stirling.${BASE_DOMAIN}`:
    - Check Traefik logs.
    - Ensure `BASE_DOMAIN` is correctly set.
    - Verify DNS records.

## Security Notes

- **Use strong, unique passwords** for `STIRLING_PASSWORD`.
- **`DOCKER_ENABLE_SECURITY=true` and `SECURITY_ENABLELOGIN=true` are highly recommended** to protect access to the tool, especially if it's exposed to untrusted networks.
- HTTPS is handled by Traefik.
- Be mindful of the types of documents you upload if the instance is shared or not fully secured.
- Regularly update Stirling PDF to the latest version (`stirlingtools/stirling-pdf:latest`) for security patches and features.

## Additional Resources
- [Stirling PDF Official Website](https://stirlingpdf.com/)
- [Stirling PDF GitHub Repository](https://github.com/Stirling-Tools/Stirling-PDF)
- [Tesseract OCR Language Data](https://github.com/tesseract-ocr/tessdata_fast) (for additional OCR languages)
