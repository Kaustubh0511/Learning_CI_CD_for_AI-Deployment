```bash
#!/bin/bash

set -e

# ============================================================
# First-time Droplet setup
# ============================================================

APP_NAME="Learning_CI_CD_for_AI-Deployment"
APP_DIR="/opt/${APP_NAME}"

REPO_URL="git@github.com:Kaustubh0511/Learning_CI_CD_for_AI-Deployment.git"
BRANCH="master"

DOCKER_IMAGE="${APP_NAME}:latest"

BLUE_PORT=8000
NGINX_CONFIG="/etc/nginx/sites-available/${APP_NAME}"

ENV_FILE="/etc/${APP_NAME}.env"

echo "=========================================="
echo " First-time Droplet Setup"
echo " ${APP_NAME}"
echo "=========================================="

# ============================================================
# Check Ubuntu / sudo
# ============================================================

if [ "$EUID" -eq 0 ]; then
    echo "Please run this script as your normal user, not root."
    exit 1
fi

# ============================================================
# Install required packages
# ============================================================

echo
echo "Installing required packages..."

sudo apt-get update

sudo apt-get install -y \
    git \
    curl \
    nginx \
    ca-certificates

# ============================================================
# Install Docker if not already installed
# ============================================================

if ! command -v docker >/dev/null 2>&1; then
    echo
    echo "Installing Docker..."

    curl -fsSL https://get.docker.com | sudo sh

    sudo systemctl enable docker
    sudo systemctl start docker

    sudo usermod -aG docker "$USER"

    echo
    echo "Docker installed."
    echo "IMPORTANT: Log out and log back in once so Docker group"
    echo "permissions take effect, then run this script again."
    exit 0
fi

echo "Docker is already installed."

# Make sure Docker is running
sudo systemctl enable docker
sudo systemctl start docker

# ============================================================
# Check Docker Compose
# ============================================================

if ! docker compose version >/dev/null 2>&1; then
    echo "ERROR: Docker Compose is not available."
    echo "Please install Docker Compose and run this script again."
    exit 1
fi

# ============================================================
# Clone repository
# ============================================================

echo
echo "Setting up application directory..."

sudo mkdir -p "$APP_DIR"
sudo chown -R "$USER:$USER" "$APP_DIR"

if [ -d "$APP_DIR/.git" ]; then
    echo "Repository already exists."
else
    echo "Cloning repository..."

    git clone \
        --branch "$BRANCH" \
        "$REPO_URL" \
        "$APP_DIR"
fi

cd "$APP_DIR"

# ============================================================
# Make sure repository is on the correct branch
# ============================================================

echo
echo "Checking repository..."

git checkout "$BRANCH"
git pull origin "$BRANCH"

# ============================================================
# Check deploy.sh
# ============================================================

if [ ! -f "$APP_DIR/deploy.sh" ]; then
    echo "ERROR: deploy.sh was not found in the repository."
    exit 1
fi

chmod +x "$APP_DIR/deploy.sh"

# ============================================================
# Environment variables
# ============================================================

echo
echo "Checking environment configuration..."

if [ ! -f "$ENV_FILE" ]; then

    echo
    echo "Creating ${ENV_FILE}"

    sudo tee "$ENV_FILE" > /dev/null <<EOF
GROQ_API_KEY=
LLM_MODEL=llama-3.1-8b-instant
EOF

    sudo chmod 600 "$ENV_FILE"

    echo
    echo "ERROR: Please edit:"
    echo "  $ENV_FILE"
    echo
    echo "Add your GROQ_API_KEY and run this script again."
    exit 1
fi

# Load environment variables
set -a
source "$ENV_FILE"
set +a

if [ -z "${GROQ_API_KEY:-}" ]; then
    echo "ERROR: GROQ_API_KEY is not configured in ${ENV_FILE}"
    exit 1
fi

# ============================================================
# Configure Nginx
# ============================================================

echo
echo "Configuring Nginx..."

sudo tee "$NGINX_CONFIG" > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${BLUE_PORT};

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -sf \
    "$NGINX_CONFIG" \
    "/etc/nginx/sites-enabled/${APP_NAME}"

# Remove default Nginx site
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

sudo systemctl enable nginx
sudo systemctl restart nginx

# ============================================================
# Build Docker image
# ============================================================

echo
echo "Building Docker image..."

cd "$APP_DIR"

docker build \
    -t "$DOCKER_IMAGE" \
    .

echo
echo "Docker image built successfully."

# ============================================================
# First deployment
#
# We explicitly start BLUE here because there is no
# existing environment yet.
# ============================================================

echo
echo "Starting first BLUE deployment..."

# Clean up anything left over from an earlier attempt
docker stop "${APP_NAME}-blue" 2>/dev/null || true
docker rm "${APP_NAME}-blue" 2>/dev/null || true

docker run -d \
    --name "${APP_NAME}-blue" \
    -e GROQ_API_KEY="${GROQ_API_KEY}" \
    -e LLM_MODEL="${LLM_MODEL:-llama-3.1-8b-instant}" \
    -p "${BLUE_PORT}:8000" \
    --restart unless-stopped \
    "$DOCKER_IMAGE"

# ============================================================
# Health check
# ============================================================

echo
echo "Waiting for application to become healthy..."

MAX_RETRIES=10
retry_count=0

until curl -sf "http://127.0.0.1:${BLUE_PORT}/health" > /dev/null; do

    retry_count=$((retry_count + 1))

    if [ "$retry_count" -ge "$MAX_RETRIES" ]; then
        echo
        echo "ERROR: Application failed health check."

        docker logs "${APP_NAME}-blue" || true

        docker stop "${APP_NAME}-blue" 2>/dev/null || true
        docker rm "${APP_NAME}-blue" 2>/dev/null || true

        exit 1
    fi

    echo "Health check attempt ${retry_count}/${MAX_RETRIES}..."
    sleep 2
done

echo
echo "Application is healthy."

# ============================================================
# Final Nginx reload
# ============================================================

sudo nginx -t
sudo systemctl reload nginx

# ============================================================
# Final status
# ============================================================

echo
echo "=========================================="
echo " First-time setup complete!"
echo "=========================================="
echo
echo "Application:"
echo "  http://<DROPLET_IP>/"
echo
echo "Environment:"
echo "  BLUE"
echo
echo "Container:"
echo "  ${APP_NAME}-blue"
echo
echo "Port:"
echo "  ${BLUE_PORT}"
echo
echo "Docker image:"
echo "  ${DOCKER_IMAGE}"
echo
echo "=========================================="

docker ps \
    --filter "name=${APP_NAME}-" \
    --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```
