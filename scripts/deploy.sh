#!/bin/bash

set -e

#Configuration
APP_NAME="Learning_CI_CD_for_AI-Deployment"
DOCKER_IMAGE="${1:?Usage: deploy.sh <docker-image>}"
BLUE_PORT=8000
GREEN_PORT=8001
NGINX_CONFIG="/etc/nginx/sites-available/${APP_NAME}"
MAX_RETRIES=10
DRAIN_WAIT=5

echo "Starting Blue Green Deployment for ${DOCKER_IMAGE}"

CURRENT_ENV=$(docker ps --filter "name=${APP_NAME}-" --format "{{.Names}}" | grep -oE "blue|green" | head -n1)

if [ "$CURRENT_ENV" = "blue" ]; then
    NEW_ENV="green"
    NEW_PORT=$GREEN_PORT
elif [ "$CURRENT_ENV" = "green" ]; then
    NEW_ENV="blue"
    NEW_PORT=$BLUE_PORT
else
    echo "No environment currently running, defaulting to blue"
    CURRENT_ENV=""
    NEW_ENV="blue"
    NEW_PORT=$BLUE_PORT
fi

NEW_CONTAINER="${APP_NAME}-${NEW_ENV}"
echo "Current: ${CURRENT_ENV:-none} | Deploying to: ${NEW_ENV} (port ${NEW_PORT})"

# Clean up any leftover container from a previous failed deploy
docker stop "$NEW_CONTAINER" 2>/dev/null || true
docker rm "$NEW_CONTAINER" 2>/dev/null || true

echo "Starting ${NEW_CONTAINER} on port ${NEW_PORT}..."
docker run -d \
    --name "$NEW_CONTAINER" \
    -e GROQ_API_KEY="${GROQ_API_KEY:?GROQ_API_KEY is not set}" \
    -e LLM_MODEL="${LLM_MODEL:-llama-3.1-8b-instant}" \
    -p "${NEW_PORT}:8000" \
    --restart unless-stopped \
    "$DOCKER_IMAGE"

echo "Waiting for ${NEW_CONTAINER} to become healthy..."
retry_count=0
until curl -sf "http://localhost:${NEW_PORT}/health" > /dev/null; do
    retry_count=$((retry_count + 1))
    if [ "$retry_count" -ge "$MAX_RETRIES" ]; then
        echo "Health check failed after ${MAX_RETRIES} retries, aborting deploy"
        docker logs "$NEW_CONTAINER" || true
        docker stop "$NEW_CONTAINER" 2>/dev/null || true
        docker rm "$NEW_CONTAINER" 2>/dev/null || true
        exit 1
    fi
    sleep 2
done
echo "${NEW_CONTAINER} is healthy"

echo "Switching Nginx to ${NEW_ENV} (port ${NEW_PORT})..."
sudo tee "$NGINX_CONFIG" > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${NEW_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
sudo ln -sf "$NGINX_CONFIG" "/etc/nginx/sites-enabled/${APP_NAME}"
sudo nginx -t
sudo systemctl reload nginx

#Waiting for connections to switch
echo "Draining old environment for ${DRAIN_WAIT}s before shutdown..."
sleep "$DRAIN_WAIT"

if [ -n "$CURRENT_ENV" ]; then
    OLD_CONTAINER="${APP_NAME}-${CURRENT_ENV}"
    echo "Stopping old environment: ${OLD_CONTAINER}"
    docker stop "$OLD_CONTAINER" 2>/dev/null || true
    docker rm "$OLD_CONTAINER" 2>/dev/null || true
fi

echo "Blue-Green deployment complete. Live environment: ${NEW_ENV} (port ${NEW_PORT})"
