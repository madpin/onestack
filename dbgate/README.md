# DBGate - Database Administration Tool

DBGate is a modern database administration tool that provides a web-based interface for managing multiple database types including PostgreSQL, MySQL, SQL Server, MongoDB, Redis, and more.

## Features

- Web-based database administration interface
- Support for multiple database types
- Query editor with syntax highlighting
- Visual database schema explorer
- Data import/export capabilities
- Connection management
- Multi-database support

## Configuration

### Environment Variables

The following environment variables are used (inherited from root .env):

- `POSTGRES_HOST` - PostgreSQL server hostname (default: postgres)
- `POSTGRES_USER` - PostgreSQL username
- `POSTGRES_PASSWORD` - PostgreSQL password
- `POSTGRES_PORT` - PostgreSQL port (default: 5432)

### Adding Additional Database Connections

You can configure multiple database connections by setting environment variables in the `.env` file:

```bash
# Multiple connections
CONNECTIONS=mypg,myredis,mymongo

# PostgreSQL connection
LABEL_mypg=Production PostgreSQL
SERVER_mypg=postgres
USER_mypg=postgres
PASSWORD_mypg=your-password
PORT_mypg=5432
ENGINE_mypg=postgres@dbgate-plugin-postgres

# Redis connection
LABEL_myredis=Redis Cache
SERVER_myredis=redis
PORT_myredis=6379
ENGINE_myredis=redis@dbgate-plugin-redis

# MongoDB connection
LABEL_mymongo=MongoDB
SERVER_mymongo=mongodb
PORT_mymongo=27017
ENGINE_mymongo=mongo@dbgate-plugin-mongo
```

## Usage

1. Start the service:
   ```bash
   make up dbgate
   ```

2. Access DBGate at: `https://dbgate.${BASE_DOMAIN}`

3. The configured database connections will be automatically available in the interface.

## Data Persistence

- Database schemas and saved queries: `./data`
- Configuration files: `./config`

## Supported Database Engines

- PostgreSQL: `postgres@dbgate-plugin-postgres`
- MySQL: `mysql@dbgate-plugin-mysql`
- SQL Server: `mssql@dbgate-plugin-mssql`
- MongoDB: `mongo@dbgate-plugin-mongo`
- Redis: `redis@dbgate-plugin-redis`
- SQLite: `sqlite@dbgate-plugin-sqlite`
- Oracle: `oracle@dbgate-plugin-oracle`

## Security Notes

- DBGate is exposed via Traefik with automatic SSL
- Database credentials are stored in environment variables
- Consider using strong passwords and network isolation
- Access is controlled through the web interface
