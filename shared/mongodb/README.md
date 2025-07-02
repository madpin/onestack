# MongoDB Service

MongoDB database service with single user supporting multiple databases.

## Configuration

### Environment Variables

The following environment variables need to be set in the root `.env` file:

```bash
# MongoDB configuration
MONGODB_HOST=mongodb  # Service name in Docker Compose
MONGODB_ROOT_USER=root
MONGODB_ROOT_PASSWORD=your-mongodb-root-password
MONGODB_USER=appuser
MONGODB_PASSWORD=your-mongodb-app-password
MONGODB_PORT=27017
```

### Local Environment

Copy `.env.template` to `.env` and configure:

```bash
cp .env.template .env
```

## Database Setup

This service creates a single user (`appuser`) with access to multiple databases:

- `librechat` - For LibreChat application
- `madpin` - For MadPin application

## Connection Strings

### LibreChat Connection

```text
mongodb://appuser:your-mongodb-app-password@mongodb:27017/librechat?authSource=admin
```

### MadPin Connection

```text
mongodb://appuser:your-mongodb-app-password@mongodb:27017/madpin?authSource=admin
```

## Adding New Databases

To add new databases:

1. Update the initialization script in `mongo-init/01-create-single-user-multiple-databases.js`
2. Add the new database role to the user creation
3. Create the database with an initial collection

## Health Check

The service includes a health check that verifies MongoDB is accessible and responding to ping commands.

## Volumes

- `./data:/data/db` - MongoDB data directory
- `./config:/data/configdb` - MongoDB configuration directory  
- `./mongo-init:/docker-entrypoint-initdb.d:ro` - Initialization scripts
