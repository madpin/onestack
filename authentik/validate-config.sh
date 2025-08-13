#!/bin/bash

# Authentik Configuration Validation Script
# This script validates the Authentik setup for OneStack

echo "🔍 Validating Authentik Configuration..."

# Check if required files exist
echo "📁 Checking required files..."
files=(".env" "docker-compose.yml" "README.md")
for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ $file exists"
    else
        echo "❌ $file is missing"
        exit 1
    fi
done

# Check if required directories exist
echo "📁 Checking required directories..."
dirs=("data/media" "data/certs" "data/custom-templates")
for dir in "${dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        echo "✅ $dir exists"
    else
        echo "❌ $dir is missing"
        exit 1
    fi
done

# Check if secret key is set
echo "🔐 Checking secret key..."
if grep -q "AUTHENTIK_SECRET_KEY=" .env && ! grep -q "AUTHENTIK_SECRET_KEY=$" .env; then
    echo "✅ Secret key is configured"
else
    echo "❌ Secret key is not configured"
    echo "Run: echo \"AUTHENTIK_SECRET_KEY=\$(openssl rand -base64 60 | tr -d '\\n')\" >> .env"
    exit 1
fi

# Validate docker-compose.yml syntax
echo "🐳 Validating docker-compose.yml syntax..."
if docker compose config > /dev/null 2>&1; then
    echo "✅ docker-compose.yml syntax is valid"
else
    echo "❌ docker-compose.yml has syntax errors"
    docker compose config
    exit 1
fi

# Check for required environment variables in .env
echo "🔧 Checking required environment variables..."
required_vars=("AUTHENTIK_SECRET_KEY" "POSTGRES_AUTHENTIK_DB" "AUTHENTIK_EMAIL_HOST" "AUTHENTIK_EMAIL_FROM")
for var in "${required_vars[@]}"; do
    if grep -q "^${var}=" .env; then
        echo "✅ $var is set"
    else
        echo "❌ $var is not set in .env"
        exit 1
    fi
done

# Check shared services dependency
echo "🔗 Checking shared services..."
shared_services=("../shared/postgres" "../shared/redis")
for service in "${shared_services[@]}"; do
    if [[ -d "$service" ]]; then
        echo "✅ $service exists"
    else
        echo "⚠️  $service not found - ensure shared services are set up"
    fi
done

echo ""
echo "🎉 Authentik configuration validation completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Ensure shared PostgreSQL and Redis services are running"
echo "2. Start Authentik: docker compose up -d"
echo "3. Access initial setup: https://authentik.madpin.dev/if/flow/initial-setup/"
echo "4. Complete admin user setup"
