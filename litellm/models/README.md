# LiteLLM Configuration Organization

This directory contains the LiteLLM configuration files organized by provider for better maintainability.

## File Structure

```
litellm/
├── config.yml                    # Main configuration file (currently in use)
├── config-organized.yml          # Organized main config (ready for future use)
├── config-backup.yml             # Backup of original config
├── models/                       # Provider-specific model configurations
│   ├── openai.yml                # OpenAI models (GPT, DALL-E, Whisper, etc.)
│   ├── anthropic.yml             # Anthropic models (Claude)
│   ├── google.yml                # Google models (Gemini, Vertex AI)
│   ├── groq.yml                  # Groq models (Llama via Groq)
│   ├── hyperbolic.yml            # Hyperbolic models
│   ├── grok.yml                  # Grok/X.AI models
│   ├── nebius.yml                # Nebius models
│   ├── deepinfra.yml             # DeepInfra models
│   ├── deepseek.yml              # DeepSeek models
│   ├── alicloud.yml              # Alicloud/Qwen models
│   ├── perplexity.yml            # Perplexity AI models
│   ├── azure.yml                 # Azure AI models
│   └── embeddings.yml            # Embedding and utility models
└── README.md                     # This file
```

## Current Status

### Active Configuration
- **`config.yml`**: Currently active configuration with all models inline
- Contains all providers and models in a single file
- Used by the running LiteLLM service

### Organized Structure (Ready for Future Use)
- **`config-organized.yml`**: Main config with organized structure
- **`models/*.yml`**: Individual provider files with their models
- **`config-backup.yml`**: Backup of original configuration

## Provider Organization

### Core Services
- **`embeddings.yml`**: Embedding and reranking models (Voyage AI)
- **`openai.yml`**: OpenAI models including paid and free tiers, media models

### Commercial Providers
- **`anthropic.yml`**: Claude models
- **`google.yml`**: Gemini models (paid, free, and Vertex AI)
- **`deepseek.yml`**: DeepSeek reasoning and chat models
- **`grok.yml`**: Grok/X.AI models
- **`perplexity.yml`**: Perplexity AI search-augmented models

### Infrastructure Providers
- **`groq.yml`**: Fast, free Llama models
- **`hyperbolic.yml`**: High-performance model hosting
- **`nebius.yml`**: Nebius AI studio models
- **`deepinfra.yml`**: DeepInfra model hosting
- **`alicloud.yml`**: Alicloud Qwen models
- **`azure.yml`**: Azure AI models

## Model Categories

### By Capability
- **Text Generation**: GPT, Claude, Gemini, Llama, Qwen, DeepSeek
- **Reasoning**: GPT o1/o3, DeepSeek-R1, Gemini thinking modes
- **Image Generation**: DALL-E 3, SDXL
- **Audio**: Whisper (transcription), TTS (speech synthesis)
- **Embeddings**: Voyage AI, OpenAI embeddings
- **Search**: Perplexity models with web search

### By Cost Structure
- **Free Tier**: OpenAI free, Google free, Groq
- **Pay-per-token**: Most commercial providers
- **Hosted**: Nebius, DeepInfra, Hyperbolic

## Usage

### Current Usage
The service currently uses `config.yml` with all models defined inline.

### Future Migration
To use the organized structure:

1. **Stop the LiteLLM service:**
   ```bash
   make down
   ```

2. **Switch to organized config:**
   ```bash
   cd litellm
   mv config.yml config-single.yml
   mv config-organized.yml config.yml
   ```

3. **Start the service:**
   ```bash
   make up
   ```

### Adding New Models

#### For Current Structure
Add models directly to `config.yml` in the appropriate provider section.

#### For Organized Structure
1. Add the model to the appropriate provider file in `models/`
2. Ensure the provider file is included in `config-organized.yml`
3. Test the configuration

## Model Naming Conventions

### Disambiguation
When the same model is available from multiple providers, we use suffixes:
- `deepseek-r1` (DeepSeek native)
- `deepseek-r1-nebius` (DeepSeek via Nebius)
- `deepseek-r1-hyperbolic` (DeepSeek via Hyperbolic)
- `deepseek-r1-azure` (DeepSeek via Azure)

### Free vs Paid
- Base name for paid models: `gpt-4.1`
- Suffix for free models: `gpt-4.1-free`

## Configuration Features

### Router Settings
- **Load balancing**: Simple shuffle strategy
- **Fallbacks**: Automatic failover between providers
- **Model aliases**: Easy-to-remember names (`best`, `good`, `cheap`, `cheapest`)
- **Rate limiting**: Per-model TPM/RPM limits
- **Caching**: Redis-based response caching

### Monitoring
- **Langfuse**: LLM observability
- **DataDog**: LLM observability
- **LogFire**: Logging and monitoring
- **PostHog**: Analytics

### Cost Management
- **Accurate pricing**: Real-time cost tracking
- **Weight-based routing**: Prefer certain providers
- **Free tier prioritization**: Higher weights for free models

## Best Practices

1. **Test configurations** before deploying
2. **Monitor costs** especially for high-volume models
3. **Use fallbacks** for critical applications
4. **Keep API keys secure** and rotate regularly
5. **Update pricing** when providers change rates
6. **Use aliases** for consistent model references across applications

## Troubleshooting

### Common Issues
- **Invalid API keys**: Check environment variables
- **Rate limits**: Adjust TPM/RPM settings
- **Model availability**: Some models may be in beta
- **Pricing changes**: Update cost_per_token values

### Monitoring
- Check LiteLLM logs for errors
- Monitor cost dashboard for unexpected charges
- Use health checks for critical models

---

## Environment Variables Required

Ensure these environment variables are set in your `.env` file:

```bash
# Core
LITELLM_MASTER_KEY=your-master-key
REDIS_URL=redis://default:password@redis:6379/0

# OpenAI
OPENAI_API_KEY=your-openai-key
OPENAI_API_KEY_FREE=your-openai-free-key

# Anthropic
ANTHROPIC_API_KEY=your-anthropic-key

# Google
GEMINI_API_KEY=your-gemini-key
GEMINI_API_KEY_FREE=your-gemini-free-key

# Other providers...
```

See `.env.template` for the complete list of required API keys.
