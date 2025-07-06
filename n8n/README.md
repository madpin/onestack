# n8n - Workflow Automation Tool

n8n is a powerful workflow automation tool that allows you to connect various apps and services together to create complex automated workflows. This OneStack deployment provides a production-ready setup with queue-based execution, database persistence, and scalable worker architecture.

## ✨ Features

- **Visual Workflow Builder**: Create complex workflows with an intuitive drag-and-drop interface
- **400+ Integrations**: Connect to popular apps and services including GitHub, Slack, Google Sheets, and more
- **Database Persistence**: Stores workflows and execution data in PostgreSQL
- **Webhook Support**: Trigger workflows via HTTP webhooks
- **Simple Architecture**: Single container deployment for easy management
- **Health Checks**: Built-in health monitoring
- **Security**: Encrypted credential storage and basic authentication

## 🏗️ Architecture

The n8n setup includes:

- **n8n**: Single n8n service that handles the web interface, API, and workflow execution
- **Shared PostgreSQL**: Database storage for workflows and execution data

## 🚀 Prerequisites

Ensure the following OneStack shared service is running:

- `postgres` - Database storage

You can start it with:

```bash
make up shared/postgres
```

## ⚙️ Configuration

### Environment Variables

Edit the `.env` file with your configuration:

```bash
# Authentication
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your_secure_password

# Security (generate a 32-character key)
N8N_ENCRYPTION_KEY=your_super_secret_encryption_key_32_chars_long

# Timezone
N8N_TIMEZONE=UTC
```

### Database Setup

n8n will automatically create the database tables on first run. The database name is configured in the root `.env` file as `POSTGRES_N8N_DB=n8n`.

### Security Configuration

- **Encryption Key**: The `N8N_ENCRYPTION_KEY` is crucial for securely storing credentials. Generate a random 32-character string.
- **Authentication**: Basic authentication is enabled by default. Use strong passwords.
- **HTTPS**: The service is configured to use HTTPS through Traefik.

## 🎯 Usage

1. **Start the service:**

   ```bash
   make up n8n
   ```

2. **Access n8n:**
   - URL: `https://n8n.your-domain.com`
   - Username: Set via `N8N_BASIC_AUTH_USER`
   - Password: Set via `N8N_BASIC_AUTH_PASSWORD`

3. **View logs:**

   ```bash
   make logs n8n
   ```

4. **Stop the service:**

   ```bash
   make down n8n
   ```

## 📁 File Structure

```text
n8n/
├── docker-compose.yml    # Service configuration
├── .env                 # Environment variables
├── .env.template        # Template for environment variables
├── README.md           # This documentation
├── config/
│   └── local-files/    # Local files accessible to workflows
└── data/               # n8n data directory (workflows, credentials, etc.)
```

## 🔧 Advanced Configuration

### File Access

Workflows can access files in the `config/local-files/` directory through the `/files` mount point within n8n.

### Custom Nodes

To add custom nodes, mount them to the container:

```yaml
volumes:
  - ./custom-nodes:/home/node/.n8n/custom
```

## 🔍 Troubleshooting

### Common Issues

1. **Database connection issues:**
   - Ensure PostgreSQL is running: `make status`
   - Check database credentials in root `.env`
   - Verify the database `n8n` exists

2. **Redis connection issues:**
   - This simplified setup doesn't use Redis
   - Workflows execute directly in the main process

3. **Authentication issues:**
   - Check `N8N_BASIC_AUTH_USER` and `N8N_BASIC_AUTH_PASSWORD` in `.env`
   - Verify basic auth is enabled: `N8N_BASIC_AUTH_ACTIVE=true`

4. **Workflow execution issues:**
   - Check main service logs: `make logs n8n`
   - Workflows execute directly in the main process
   - Check for any error messages in the n8n interface

5. **SSL/Domain issues:**
   - Verify `BASE_DOMAIN` in root `.env`
   - Check Traefik configuration and certificates
   - Ensure DNS points to your server

### Health Checks

The service includes health checks that can be monitored:

```bash
# Check service health
docker ps | grep n8n
docker inspect n8n | grep -A 10 Health
```

## 🔗 Integration Examples

### Webhook Triggers

Create webhooks at: `https://n8n.your-domain.com/webhook/your-webhook-name`

### API Access

n8n provides a REST API at: `https://n8n.your-domain.com/api/v1/`

### Popular Integrations

- **GitHub**: Automate issue management and deployments
- **Slack**: Send notifications and process messages
- **Google Sheets**: Sync data and create reports
- **Email**: Send notifications and process incoming emails
- **Databases**: Connect to PostgreSQL, MySQL, MongoDB
- **Cloud Services**: AWS, Google Cloud, Azure integrations

## 📚 Additional Resources

- [n8n Documentation](https://docs.n8n.io/)
- [n8n Community](https://community.n8n.io/)
- [Workflow Templates](https://n8n.io/workflows/)
- [Node Reference](https://docs.n8n.io/integrations/builtin/)

## 🤝 Contributing

To contribute to this OneStack n8n configuration:

1. Test your changes thoroughly
2. Update documentation
3. Follow OneStack conventions
4. Submit a pull request

## Security Notes

- Change default passwords before production use
- Generate a strong 32-character encryption key
- Use HTTPS in production (handled by Traefik)
- Consider restricting access via Traefik middleware if needed

## Links

- [n8n Documentation](https://docs.n8n.io/)
- [n8n Community](https://community.n8n.io/)
- [n8n GitHub](https://github.com/n8n-io/n8n)
