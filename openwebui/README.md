# OpenWebUI

OpenWebUI is a comprehensive web interface for Large Language Models (LLMs) with support for multiple providers and pipelines.

## 🚀 Features

- **Multi-Model Support**: Compatible with OpenAI, Anthropic, and other LLM providers
- **Pipeline System**: Extensible pipeline architecture for custom workflows
- **User Management**: Built-in authentication and user management
- **Chat Interface**: Clean, responsive chat interface
- **Model Management**: Easy model switching and configuration
- **Plugin System**: Support for extensions and custom functionality

## 📋 Services

This deployment includes:

- **OpenWebUI**: Main web interface (`openwebui.${BASE_DOMAIN}`)
- **Pipelines**: Background processing service for custom workflows

## 🛠️ Configuration

### Environment Variables

Copy `.env.template` to `.env` and configure:

```bash
# Basic configuration
cp .env.template .env
```

### Key Configuration Options

- `DATABASE_URL`: PostgreSQL connection string (optional, defaults to SQLite)
- `OPENAI_API_KEY`: OpenAI API key for GPT models
- `LITELLM_ENDPOINT`: LiteLLM proxy endpoint if using
- `SECRET_KEY`: Secret key for session management
- `DEFAULT_USER_ROLE`: Default role for new users
- `ENABLE_SIGNUP`: Allow user registration

## 🔧 Setup

1. **Configure environment**:

   ```bash
   cd openwebui
   cp .env.template .env
   # Edit .env with your values
   ```

2. **Start services**:

   ```bash
   # From the root directory
   make up
   ```

3. **Access OpenWebUI**:
   - URL: `https://openwebui.${BASE_DOMAIN}`
   - First user to register becomes admin

## 📁 Directory Structure

```text
openwebui/
├── docker-compose.yml    # Service definitions
├── .env.template        # Environment template
├── .env                 # Your configuration
├── README.md           # This file
├── data/               # OpenWebUI data and models
├── pipelines/          # Custom pipeline definitions
└── config/             # Configuration files
```

## 🔗 Integration

### LiteLLM Integration

To use with the LiteLLM proxy service:

```bash
# In .env
LITELLM_ENDPOINT=http://litellm:4000
LITELLM_API_KEY=your-litellm-master-key
```

### Database Integration

For production use with PostgreSQL:

```bash
# In .env
DATABASE_URL=postgresql://user:password@postgres:5432/openwebui
```

## 🛡️ Security

- Uses Traefik for automatic SSL certificates
- Configurable authentication methods
- User role management
- Secret key for session security

## 📖 Usage

1. **Access the interface**: Navigate to `https://openwebui.${BASE_DOMAIN}`
2. **Register**: Create your admin account (first user becomes admin)
3. **Configure models**: Add your API keys and model endpoints
4. **Start chatting**: Use the chat interface to interact with LLMs

## 🔧 Troubleshooting

- **Check logs**: `make logs-openwebui`
- **Health check**: Service includes health monitoring
- **Data persistence**: Data is stored in `./data/` directory
- **Pipeline logs**: `make logs SERVICE=openwebui-pipelines`

## 🔄 Updates

To update OpenWebUI:

```bash
# Pull latest images
make down
docker compose pull
make up
```

## 📚 Documentation

- [OpenWebUI GitHub](https://github.com/open-webui/open-webui)
- [OpenWebUI Documentation](https://docs.openwebui.com)
- [Pipeline Documentation](https://github.com/open-webui/pipelines)
