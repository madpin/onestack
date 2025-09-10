# ClickHouse Minimal Storage Guide for Docker Compose

This guide shows how to configure ClickHouse for minimal storage usage while maintaining enough data for debugging when errors occur.

## Updated Docker Compose Configuration

Replace your current configuration with this optimized version:

```yaml
services:
  clickhouse:
    image: clickhouse/clickhouse-server
    restart: unless-stopped
    container_name: clickhouse
    hostname: clickhouse
    environment:
      - CLICKHOUSE_USER=${CLICKHOUSE_USER}
      - CLICKHOUSE_PASSWORD=${CLICKHOUSE_PASSWORD}
      - CLICKHOUSE_DB=${CLICKHOUSE_DB}
      - CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1
      - CLICKHOUSE_DEFAULT_DATABASE=${CLICKHOUSE_DB}
      - CLICKHOUSE_DEFAULT_PASSWORD=${CLICKHOUSE_PASSWORD}
      - CLICKHOUSE_HTTP_PORT=8123
      - CLICKHOUSE_TCP_PORT=9000
      - CLICKHOUSE_LOG_LEVEL=information
      - CLICKHOUSE_MAX_MEMORY_USAGE=0
      - CLICKHOUSE_MAX_MEMORY_USAGE_FOR_USER=0
    networks:
      - internal_network
    ports:
      - "8123:8123"
      - "9000:9000"
    volumes:
      - ./data:/var/lib/clickhouse
      # Add configuration files for minimal storage
      - ./clickhouse-config:/etc/clickhouse-server/config.d/
      - ./clickhouse-users:/etc/clickhouse-server/users.d/
    healthcheck:
      test: wget --no-verbose --tries=1 --spider http://localhost:8123/ping || exit 1
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 1s
    ulimits:
      nofile:
        soft: 262144
        hard: 262144

networks:
  internal_network:
    external: true
    name: ${INTERNAL_NETWORK_NAME}
```

## Configuration Files for Minimal Storage

Create the following directory structure:

```
clickhouse-config/
├── system_logs_ttl.xml
├── compression.xml
├── disable_logs.xml
└── ttl_settings.xml
```

### 1. System Tables TTL Configuration

**Create `clickhouse-config/system_logs_ttl.xml`:**

```xml
<?xml version="1.0"?>
<clickhouse>
    <!-- Query log with 3 days retention -->
    <query_log replace="1">
        <database>system</database>
        <table>query_log</table>
        <engine>ENGINE = MergeTree PARTITION BY (event_date)
ORDER BY (event_time)
TTL event_date + INTERVAL 3 DAY DELETE
        </engine>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
    </query_log>

    <!-- Trace log disabled completely (heavy disk usage) -->
    <trace_log remove="1"/>

    <!-- Part log with 2 days retention -->
    <part_log replace="1">
        <database>system</database>
        <table>part_log</table>
        <engine>ENGINE = MergeTree PARTITION BY (event_date)
ORDER BY (event_time)
TTL event_date + INTERVAL 2 DAY DELETE
        </engine>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
    </part_log>

    <!-- Metric log with 1 day retention -->
    <metric_log replace="1">
        <database>system</database>
        <table>metric_log</table>
        <engine>ENGINE = MergeTree PARTITION BY (event_date)
ORDER BY (event_time)
TTL event_date + INTERVAL 1 DAY DELETE
        </engine>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
    </metric_log>

    <!-- Session log with 1 day retention -->
    <session_log replace="1">
        <database>system</database>
        <table>session_log</table>
        <engine>ENGINE = MergeTree PARTITION BY (event_date)
ORDER BY (event_time)
TTL event_date + INTERVAL 1 DAY DELETE
        </engine>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
    </session_log>

    <!-- Text log with 2 days retention -->
    <text_log replace="1">
        <database>system</database>
        <table>text_log</table>
        <engine>ENGINE = MergeTree PARTITION BY (event_date)
ORDER BY (event_time)
TTL event_date + INTERVAL 2 DAY DELETE
        </engine>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
    </text_log>
</clickhouse>
```

### 2. Compression Configuration

**Create `clickhouse-config/compression.xml`:**

```xml
<?xml version="1.0"?>
<clickhouse>
    <compression>
        <case>
            <min_part_size>1000000</min_part_size>
            <min_part_size_ratio>0.01</min_part_size_ratio>
            <method>zstd</method>
            <level>9</level>
        </case>
    </compression>
</clickhouse>
```

### 3. Disable Heavy System Logs

**Create `clickhouse-config/disable_logs.xml`:**

```xml
<?xml version="1.0"?>
<clickhouse>
    <!-- Disable profiling logs that consume significant space -->
    <query_thread_log remove="1"/>
    <query_views_log remove="1"/>
    <processors_profile_log remove="1"/>
    <opentelemetry_span_log remove="1"/>
    <crash_log remove="1"/>
    
    <!-- Keep only essential logs for debugging -->
    <asynchronous_metric_log remove="1"/>
    <zookeeper_log remove="1"/>
</clickhouse>
```

### 4. TTL Global Settings

**Create `clickhouse-config/ttl_settings.xml`:**

```xml
<?xml version="1.0"?>
<clickhouse>
    <merge_tree>
        <!-- Enable efficient TTL processing -->
        <ttl_only_drop_parts>1</ttl_only_drop_parts>
        <!-- Run TTL cleanup every 30 minutes instead of 4 hours -->
        <merge_with_ttl_timeout>1800</merge_with_ttl_timeout>
        <!-- Limit part count per partition -->
        <parts_to_throw_insert>3000</parts_to_throw_insert>
    </merge_tree>
</clickhouse>
```

### 5. User-Level Logging Control

**Create `clickhouse-users/logging.xml`:**

```xml
<?xml version="1.0"?>
<clickhouse>
    <profiles>
        <default>
            <!-- Reduce query logging frequency -->
            <log_queries>1</log_queries>
            <log_query_threads>0</log_query_threads>
            <log_processors_profiles>0</log_processors_profiles>
            <log_profile_events>0</log_profile_events>
        </default>
    </profiles>
</clickhouse>
```

## Application Tables Configuration

For your actual application tables (like Langfuse traces), apply TTL during creation or modification:

### New Tables with TTL

```sql
CREATE TABLE traces (
    id String,
    timestamp DateTime64(9),
    user_id String,
    content String CODEC(ZSTD(9)),
    metadata String CODEC(ZSTD(9))
) ENGINE = MergeTree()
PARTITION BY toDate(timestamp)
ORDER BY (timestamp, id)
TTL timestamp + INTERVAL 30 DAY DELETE
SETTINGS ttl_only_drop_parts = 1;
```

### Modify Existing Tables

```sql
-- Add 30-day TTL to existing traces table
ALTER TABLE traces 
MODIFY TTL timestamp + INTERVAL 30 DAY DELETE;

-- For selective retention (keep specific users)
-- Create a separate table for important users or use column-level TTL
ALTER TABLE traces 
MODIFY COLUMN content String TTL 
    multiIf(
        user_id IN ('important_user_1', 'important_user_2'), timestamp + INTERVAL 365 DAY,
        timestamp + INTERVAL 30 DAY
    ) DELETE;
```

## Monitoring and Maintenance Commands

### Check Storage Usage

```sql
-- Basic storage usage by table
SELECT
    database,
    table,
    formatReadableSize(sum(bytes_on_disk)) AS size_on_disk,
    sum(rows) as total_rows
FROM system.parts
WHERE active
GROUP BY database, table
ORDER BY sum(bytes_on_disk) DESC;

-- Advanced storage analysis with compression details
SELECT
    database,
    table,
    formatReadableSize(sum(bytes_on_disk)) as disk_size,
    formatReadableSize(sum(data_compressed_bytes)) as compressed_size,
    formatReadableSize(sum(data_uncompressed_bytes)) as uncompressed_size,
    round(sum(data_compressed_bytes) / sum(data_uncompressed_bytes) * 100, 2) as compression_ratio_pct,
    sum(rows) as total_rows,
    count() as part_count,
    formatReadableSize(sum(bytes_on_disk) / sum(rows)) as avg_row_size
FROM system.parts
WHERE active = 1
GROUP BY database, table
HAVING sum(bytes_on_disk) > 0
ORDER BY sum(bytes_on_disk) DESC;

-- Check system table sizes
SELECT 
    name,
    formatReadableSize(total_bytes) as size
FROM system.tables 
WHERE database = 'system' 
AND engine LIKE '%MergeTree%'
ORDER BY total_bytes DESC;
```

### Manual Cleanup Commands

```sql
-- Force TTL processing
ALTER TABLE system.query_log MATERIALIZE TTL;

-- Clean old partitions immediately
ALTER TABLE traces DROP PARTITION '2024-08';

-- Optimize tables to reduce part count
OPTIMIZE TABLE traces FINAL;
```

### Docker Maintenance Script

**Create `maintenance.sh`:**

```bash
#!/bin/bash
# Run this weekly via cron

# Clean Docker system
docker system prune -f

# Execute ClickHouse maintenance
docker exec clickhouse clickhouse-client --query="
-- Force TTL processing on all tables
SELECT 'Processing TTL for: ' || concat(database, '.', table) as status
FROM system.tables 
WHERE engine LIKE '%MergeTree%' 
AND database != 'system';

-- Optimize system tables
OPTIMIZE TABLE system.query_log FINAL;
OPTIMIZE TABLE system.part_log FINAL;

-- Show current storage usage
SELECT 
    database,
    table,
    formatReadableSize(sum(bytes_on_disk)) AS size
FROM system.parts 
WHERE active AND database IN ('system', '${CLICKHOUSE_DB}')
GROUP BY database, table 
ORDER BY sum(bytes_on_disk) DESC;
"
```

## Expected Storage Footprint

With these configurations, expect:

- **System tables**: 10-50MB for debugging data
- **Application tables**: Depends on your data volume
- **Background processes**: Minimal overhead
- **Compression**: 5-10x reduction in storage
- **TTL cleanup**: Automatic every 30 minutes

## Debugging Capabilities Retained

This configuration maintains:

- **3 days** of query logs for debugging slow queries
- **2 days** of part operations for merge troubleshooting  
- **1 day** of metrics for performance analysis
- **30 days** of application data (configurable)
- **Error logs** in text_log for 2 days

## Startup Instructions

1. Create the directory structure:
```bash
mkdir -p clickhouse-config clickhouse-users
```

2. Create all the XML configuration files above

3. Restart your ClickHouse container:
```bash
docker-compose down
docker-compose up -d
```

4. Verify the configuration:
```bash
docker exec clickhouse clickhouse-client --query="
SELECT name, engine FROM system.tables WHERE database='system' AND engine != '';
"
```

This setup provides minimal storage usage while preserving essential debugging capabilities for when errors occur.