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

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GIT_COMMIT=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || true)
GIT_BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
GIT_COMMIT_TIME=$(git -C "$REPO_ROOT" log -1 --format=%cI 2>/dev/null || true)

# Create and use a new builder instance
docker buildx create --name multiarch-builder --use

# Build with appropriate flags based on push vs local
docker buildx build \
  --platform $PLATFORM \
  --build-arg GIT_COMMIT="$GIT_COMMIT" \
  --build-arg GIT_BRANCH="$GIT_BRANCH" \
  --build-arg GIT_COMMIT_TIME="$GIT_COMMIT_TIME" \
  -t pathsny/cisqua:latest \
  -f Dockerfile \
  $ACTION \
  ..

# Remove the builder instance
docker buildx rm multiarch-builder
