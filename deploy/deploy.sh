#!/bin/bash
# Usage: deploy.sh <image-tag> <ecr-registry>
set -euo pipefail

TAG="$1"
REGISTRY="$2"
REGION="ap-south-1"

cd /opt/app

echo "Logging in to ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

# Keep the previous version for rollback
if [ -f .env ]; then
  cp .env .env.previous
fi

printf "REGISTRY=%s\nIMAGE_TAG=%s\n" "$REGISTRY" "$TAG" > .env

echo "Deploying version $TAG..."
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d --remove-orphans
docker compose -f docker-compose.prod.yml restart nginx

docker image prune -f
echo "Deployed version $TAG"