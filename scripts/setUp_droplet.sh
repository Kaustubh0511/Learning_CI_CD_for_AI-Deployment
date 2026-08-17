#!/bin/bash

set -e

# ============================================================
# Configuration
# ============================================================

APP_NAME="Learning_CI_CD_for_AI-Deployment"
APP_DIR="/opt/${APP_NAME}"

REPO_URL="git@github.com:Kaustubh0511/Learning_CI_CD_for_AI-Deployment.git"
BRANCH="main"

DOCKER_IMAGE="${APP_NAME}:latest"
ENV_FILE="/etc/${APP_NAME}.env"

echo "=========================================="
echo " Setting up ${APP_NAME}"
echo "=========================================="

# ============================================================
# Check required commands
# ============================================================

echo "Checking required dependencies..."

command -v git >/dev/null 2>&1 || {
    echo "ERROR: git is not installed."
    exit 1
}

command -v docker >/dev/null 2>&1 || {
    echo "ERROR: docker is not installed."
    exit 1
}

command -v nginx >/dev/null 2>&1 || {
    echo "ERROR: nginx is not installed."
    exit 1
}

echo "Dependencies OK."

# ============================================================
# Create application directory
# ============================================================

echo "Creating application directory..."

sudo mkdir -p "$APP_DIR"
sudo chown -R "$USER:$USER" "$APP_DIR"

# ============================================================
# Clone or update repository
# ============================================================

if [ -d "$APP_DIR/.git" ]; then
    echo "Repository already exists. Pulling latest ${BRANCH}..."

    cd "$APP_DIR"

    git fetch origin
    git checkout "$BRANCH"
    git reset --hard "origin/${BRANCH}"

else
    echo "Cloning repository..."

    git clone \
        --branch "$BRANCH" \
        "$REPO_URL" \
        "$APP_DIR"

    cd "$APP_DIR"
fi

echo "Repository ready."

# ============================================================
# Check deploy script
# ============================================================

if [ ! -f "$APP_DIR/deploy.sh" ]; then
    echo "ERROR: deploy.sh not found in repository."
    exit 1
fi

chmod +x "$APP_DIR/deploy.sh"

# ============================================================
# Load environment variables
# ============================================================

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: Environment file not found:"
    echo "$ENV_FILE"
    echo
    echo "Create it with at least:"
    echo
    echo "GROQ_API_KEY=your-api-key"
    echo "LLM_MODEL=llama-3.1-8b-instant"
    exit 1
fi

echo "Loading environment variables..."

set -a
source "$ENV_FILE"
set +a

if [ -z "${GROQ_API_KEY:-}" ]; then
    echo "ERROR: GROQ_API_KEY is not set."
    exit 1
fi

# ============================================================
# Build Docker image
# ============================================================

echo "Building Docker image: ${DOCKER_IMAGE}"

cd "$APP_DIR"

docker build \
    -t "$DOCKER_IMAGE" \
    .

echo "Docker image built successfully."

# ============================================================
# Run blue-green deployment
# ============================================================

echo "Starting blue-green deployment..."

"$APP_DIR/deploy.sh" "$DOCKER_IMAGE"

# ============================================================
# Final status
# ============================================================

echo
echo "=========================================="
echo " Deployment complete"
echo "=========================================="

docker ps \
    --filter "name=${APP_NAME}-" \
    --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"