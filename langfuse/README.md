# Langfuse

[Langfuse](https://langfuse.com) is an open-source observability and analytics platform for LLM applications.

## Features

- Tracing and monitoring for LLM applications
- Cost tracking and analytics
- Prompt management and testing
- Performance monitoring
- User feedback collection
- Model comparison

## Setup Instructions

1. Copy the `.env.template` file to `.env`:

   ```bash
   cp .env.template .env
   ```

2. Update the variables in the `.env` file with your actual values:
   - Database configuration
   - S3/Object storage configuration
   - Redis configuration
   - Authentication settings

3. Start the Langfuse services:

   ```bash
   docker-compose up -d
   ```

4. Access the Langfuse web interface at: `https://langfuse.yourdomain.com`

## Components

This setup includes:

- **langfuse-web**: The main web interface for Langfuse
- **langfuse-worker**: Background processing worker for Langfuse

## Dependencies

This deployment relies on:

- PostgreSQL database (with pgvector extension)
- ClickHouse for analytics
- Redis for queue management
- S3-compatible object storage

## Configuration

See the `.env.template` file for all available configuration options.

## Resources

- [Langfuse Documentation](https://langfuse.com/docs)
- [GitHub Repository](https://github.com/langfuse/langfuse)
