#!/bin/bash

# Default to load (for local testing)
ACTION="--load"
PLATFORM="linux/$(uname -m | sed 's/x86_64/amd64/' | sed 's/arm64/arm64/')"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --push)
      ACTION="--push"
      PLATFORM="linux/amd64,linux/arm64"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Create and use a new builder instance
docker buildx create --name multiarch-builder --use

# Build with appropriate flags based on push vs local
docker buildx build \
  --platform $PLATFORM \
  -t pathsny/cisqua:latest \
  -f Dockerfile \
  $ACTION \
  ..

# Remove the builder instance
docker buildx rm multiarch-builder
