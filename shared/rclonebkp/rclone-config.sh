#!/bin/bash

# Rclone configuration script for OneStack backup

set -e

echo "🔧 OneStack Rclone Backup Configuration"
echo "========================================"

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Function to configure rclone
configure_rclone() {
    echo "📁 Configuring rclone remote..."
    echo "You need to set up a remote named 'pcloud' (or change RCLONE_REMOTE_NAME in .env)"
    echo ""
    
    docker run --rm -it \
        --mount type=bind,source="$(dirname "$(realpath "$0")")/config",target=/config/ \
        adrienpoupa/rclone-backup:latest \
        rclone config
}

# Function to show rclone configuration
show_config() {
    echo "📋 Current rclone configuration:"
    docker run --rm -it \
        --mount type=bind,source="$(dirname "$(realpath "$0")")/config",target=/config/ \
        adrienpoupa/rclone-backup:latest \
        rclone config show
}

# Function to test rclone connection
test_connection() {
    echo "🔍 Testing rclone connection to pcloud..."
    if docker run --rm -it \
        --mount type=bind,source="$(dirname "$(realpath "$0")")/config",target=/config/ \
        adrienpoupa/rclone-backup:latest \
        rclone lsd pcloud: > /dev/null 2>&1; then
        echo "✅ Connection to pcloud successful!"
    else
        echo "❌ Connection to pcloud failed. Please check your configuration."
        return 1
    fi
}

# Function to create backup directory
create_backup_dir() {
    echo "📁 Creating backup directory..."
    docker run --rm -it \
        --mount type=bind,source="$(dirname "$(realpath "$0")")/config",target=/config/ \
        adrienpoupa/rclone-backup:latest \
        rclone mkdir pcloud:/backup_onestack/
    echo "✅ Backup directory created at pcloud:/backup_onestack/"
}

# Function to test email configuration
test_email() {
    echo "📧 Testing email configuration..."
    if [ -f .env ]; then
        docker run --rm -it \
            --env-file .env \
            adrienpoupa/rclone-backup:latest \
            mail success
    else
        echo "❌ .env file not found. Please create it first."
        return 1
    fi
}

# Function to run backup now
run_backup() {
    echo "🚀 Running backup now..."
    
    # Check if the services are running
    if ! docker compose ps | grep -q rclonebkp; then
        echo "❌ No rclone backup services are running. Please start them first with:"
        echo "   docker compose up -d"
        return 1
    fi
    
    # Function to trigger backup for a specific service
    trigger_service_backup() {
        local service_name=$1
        local container_name=$2
        
        echo "📦 Triggering backup for $service_name..."
        
        if docker compose ps | grep -q "$container_name"; then
            # Run the backup script directly in the container
            docker compose exec "$service_name" /app/backup.sh
            if [ $? -eq 0 ]; then
                echo "✅ Backup completed successfully for $service_name"
            else
                echo "❌ Backup failed for $service_name"
                return 1
            fi
        else
            echo "⚠️  Service $service_name is not running, skipping..."
        fi
    }
    
    # Trigger backup for all services
    trigger_service_backup "rclonebkp-folders" "rclonebkp-folders"
    trigger_service_backup "rclonebkp-db-paperless" "rclonebkp-db-paperless"
    trigger_service_backup "rclonebkp-db-litellm" "rclonebkp-db-litellm"
    
    echo "🎉 All backup processes completed!"
}

# Main menu
case "${1:-}" in
    "config")
        configure_rclone
        ;;
    "show")
        show_config
        ;;
    "test")
        test_connection
        ;;
    "create-dir")
        create_backup_dir
        ;;
    "test-email")
        test_email
        ;;
    "backup")
        run_backup
        ;;
    "setup")
        echo "🚀 Running full setup..."
        configure_rclone
        echo ""
        show_config
        echo ""
        test_connection
        echo ""
        create_backup_dir
        echo "✅ Setup complete!"
        ;;
    *)
        echo "Usage: $0 {config|show|test|create-dir|test-email|backup|setup}"
        echo ""
        echo "Commands:"
        echo "  config     - Configure rclone remote"
        echo "  show       - Show current rclone configuration"
        echo "  test       - Test connection to pcloud"
        echo "  create-dir - Create backup directory on pcloud"
        echo "  test-email - Test email notification"
        echo "  backup     - Run backup now (all services)"
        echo "  setup      - Run full setup (recommended for first time)"
        echo ""
        echo "Example:"
        echo "  $0 setup    # First time setup"
        echo "  $0 test     # Test connection"
        echo "  $0 backup   # Run backup immediately"
        ;;
esac
