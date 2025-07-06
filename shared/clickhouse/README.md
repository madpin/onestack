# Shared ClickHouse Service

ClickHouse is a fast, open-source, column-oriented database management system that allows generating analytical data reports in real-time. This shared service provides a centralized ClickHouse instance for all applications in the OneStack ecosystem.

## Overview

- **Service Name**: `clickhouse`
- **Container Name**: `clickhouse`
- **Image**: `clickhouse/clickhouse-server`
- **Ports**: 
  - `8123`: HTTP interface
  - `9000`: Native TCP protocol
- **Networks**: `internal_network`
- **Data Location**: `${HOME}/configs/clickhouse/data`

## Prerequisites

- Docker and Docker Compose installed.
- The `internal_network` Docker network must be created (usually handled by the global setup script).
- Directory `${HOME}/configs/clickhouse/data` must exist and be writable by the container.

## Dependencies

- **None directly** - ClickHouse is a self-contained database service.
- **Dependent Services**: Any application that needs fast analytical queries or real-time data processing can use this ClickHouse instance.

## Configuration

- ClickHouse settings are managed through environment variables in the root `.env` file.
- All configuration is centralized in the project root `.env` file to avoid redundancy.

### Key Environment Variables

**In root `.env`:**
- `CLICKHOUSE_USER`: Username for ClickHouse access (set to `madpin`)
- `CLICKHOUSE_PASSWORD`: Password for the ClickHouse user
- `CLICKHOUSE_DB`: Default database name
- `CLICKHOUSE_HOST`: Service name for internal connections (`clickhouse`)
- `CLICKHOUSE_PORT_HTTP`: HTTP interface port (`8123`)
- `CLICKHOUSE_PORT_NATIVE`: Native TCP port (`9000`)
- `CLICKHOUSE_ADDR`: Full HTTP address for service connections
- `INTERNAL_NETWORK_NAME`: Docker network name for internal communication

### Volume Mounts

- `./data:/var/lib/clickhouse`: Persistent storage for ClickHouse data and metadata

### Health Check

The service includes a health check that verifies the HTTP interface is responding:
- **Test**: `wget --no-verbose --tries=1 --spider http://localhost:8123/ping`
- **Interval**: 5 seconds
- **Timeout**: 5 seconds
- **Retries**: 10
- **Start Period**: 1 second

### Resource Limits

- **File Descriptor Limits**: 
  - Soft limit: 262,144
  - Hard limit: 262,144

## Usage

### Starting the Service

```bash
# From the onestack root directory
make up clickhouse

# Or directly with docker-compose
cd shared/clickhouse
docker-compose up -d
```

### Accessing ClickHouse

**HTTP Interface (Web UI and REST API):**
```bash
# Web interface
http://localhost:8123/play

# REST API example
curl "http://localhost:8123/" -d "SELECT version()"
```

**Native TCP Client:**
```bash
# Using clickhouse-client
clickhouse-client --host localhost --port 9000 --user madpin --password YOUR_PASSWORD
```

### Basic Operations

**Create a database:**
```sql
CREATE DATABASE analytics;
```

**Create a table:**
```sql
CREATE TABLE analytics.events (
    timestamp DateTime,
    event_type String,
    user_id UInt64,
    properties String
) ENGINE = MergeTree()
ORDER BY timestamp;
```

**Insert data:**
```sql
INSERT INTO analytics.events VALUES 
    ('2025-01-01 12:00:00', 'page_view', 1, '{"page": "/home"}'),
    ('2025-01-01 12:01:00', 'click', 1, '{"button": "signup"}');
```

**Query data:**
```sql
SELECT event_type, count() as event_count 
FROM analytics.events 
GROUP BY event_type;
```

## Integration with Other Services

Services can connect to ClickHouse using the following connection details:

- **Host**: `clickhouse` (internal network)
- **HTTP Port**: `8123`
- **Native Port**: `9000`
- **User**: `madpin`
- **Password**: From `CLICKHOUSE_PASSWORD` environment variable
- **Database**: `default` (or create custom databases)

### Example Connection Strings

**HTTP/REST API:**
```
http://clickhouse:8123/
```

**JDBC:**
```
jdbc:clickhouse://clickhouse:8123/default
```

**Python (clickhouse-driver):**
```python
from clickhouse_driver import Client

client = Client(
    host='clickhouse',
    port=9000,
    user='madpin',
    password='YOUR_PASSWORD',
    database='default'
)
```

## Monitoring and Maintenance

### Log Access

```bash
# View ClickHouse logs
docker logs clickhouse

# Follow logs in real-time
docker logs -f clickhouse
```

### Performance Monitoring

ClickHouse provides built-in system tables for monitoring:

```sql
-- Check system metrics
SELECT * FROM system.metrics;

-- Check query log
SELECT * FROM system.query_log ORDER BY event_time DESC LIMIT 10;

-- Check table sizes
SELECT 
    database,
    table,
    formatReadableSize(total_bytes) as size
FROM system.tables 
WHERE total_bytes > 0 
ORDER BY total_bytes DESC;
```

### Backup and Recovery

```bash
# Backup data directory
sudo cp -r ${HOME}/configs/clickhouse/data ${HOME}/configs/clickhouse/data.backup

# For production, consider using ClickHouse's built-in backup functionality
# or implement automated backup scripts
```

## Security Considerations

- The service is only accessible via the internal network, not exposed to the public internet.
- Change default passwords in production environments.
- Consider implementing proper user management and access controls for production use.
- Regular security updates of the ClickHouse image.

## Troubleshooting

### Common Issues

1. **Container fails to start**: Check if the data directory exists and has proper permissions
2. **Connection refused**: Verify the service is running and network connectivity
3. **Permission denied**: Ensure the data directory is writable by the container user
4. **Health check failing**: Check if ClickHouse is properly initialized and responding

### Useful Commands

```bash
# Check service status
docker-compose ps

# View detailed logs
docker-compose logs clickhouse

# Execute queries directly
docker-compose exec clickhouse clickhouse-client --user madpin --password YOUR_PASSWORD

# Check resource usage
docker stats clickhouse
```

## Links

- [ClickHouse Official Documentation](https://clickhouse.com/docs)
- [ClickHouse Docker Hub](https://hub.docker.com/r/clickhouse/clickhouse-server)
- [ClickHouse GitHub Repository](https://github.com/ClickHouse/ClickHouse)
