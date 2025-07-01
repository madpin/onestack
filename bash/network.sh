#!/bin/bash

# Load environment variables from .env file in the parent directory
set -o allexport
source "$(dirname "$0")/../.env"
set +o allexport

# Check if NETWORK_NAME is set
if [ -z "$NETWORK_NAME" ]; then
  echo "Error: NETWORK_NAME is not set in .env file"
  exit 1
fi

# Check if the network already exists
if ! docker network ls | grep -q "$NETWORK_NAME"; then
  echo "Creating Docker network: $NETWORK_NAME"
  docker network create "$NETWORK_NAME"
  echo "Network '$NETWORK_NAME' created successfully."
else
  echo "Docker network '$NETWORK_NAME' already exists."
fi