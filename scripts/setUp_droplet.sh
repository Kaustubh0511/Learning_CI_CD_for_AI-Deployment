#!/bin/bash

set -e

# ============================================================
# First-time Droplet setup
# ============================================================

APP_NAME="Learning_CI_CD_for_AI-Deployment"
APP_DIR="/opt/${APP_NAME}"
IMAGE_NAME="${APP_NAME,,}"

REPO_URL="git@github.com:Kaustubh0511/Learning_CI_CD_for_AI-Deployment.git"
BRANCH="master"

DOCKER_IMAGE="${IMAGE_NAME}:latest"

ENV_FILE="/etc/${APP_NAME}.env"

echo "=========================================="
echo " First-time Droplet Setup"
echo " ${APP_NAME}"
echo "=========================================="

# ============================================================
# Root vs normal user
#
# Both are supported: as root, "sudo" is skipped entirely and
# the docker-group/passwordless-sudo steps (which only exist to
# let a normal user run docker/systemctl without a password)
# are unnecessary, since root already can.
# ============================================================

if [ "$EUID" -eq 0 ]; then
    SUDO=""
    RUN_USER="root"
else
    SUDO="sudo"
    RUN_USER="$USER"
fi

# ============================================================
# Install required packages
# ============================================================

echo
echo "Installing required packages..."

$SUDO apt-get update

$SUDO apt-get install -y \
    git \
    curl \
    nginx \
    ufw \
    ca-certificates

# ============================================================
# Install Docker if not already installed
# ============================================================

if ! command -v docker >/dev/null 2>&1; then
    echo
    echo "Installing Docker..."

    curl -fsSL https://get.docker.com | $SUDO sh

    $SUDO systemctl enable docker
    $SUDO systemctl start docker

    if [ "$RUN_USER" != "root" ]; then
        $SUDO usermod -aG docker "$RUN_USER"

        echo
        echo "Docker installed."
        echo "IMPORTANT: Log out and log back in once so Docker group"
        echo "permissions take effect, then run this script again."
        exit 0
    fi

    echo
    echo "Docker installed."
else
    echo "Docker is already installed."
fi

# Make sure Docker is running
$SUDO systemctl enable docker
$SUDO systemctl start docker

# ============================================================
# Passwordless sudo for automated deploys (normal user only)
#
# deploy.sh runs nginx/systemctl commands over SSH from
# GitHub Actions, which cannot answer a sudo password prompt.
# Root already has full privileges, so this is skipped for it.
# ============================================================

if [ "$RUN_USER" != "root" ]; then
    echo
    echo "Allowing $RUN_USER passwordless sudo for automated deploys..."

    SUDOERS_FILE="/etc/sudoers.d/${RUN_USER}-deploy"
    echo "$RUN_USER ALL=(ALL) NOPASSWD: ALL" | $SUDO tee "$SUDOERS_FILE" > /dev/null
    $SUDO chmod 440 "$SUDOERS_FILE"
    $SUDO visudo -cf "$SUDOERS_FILE"
fi

# ============================================================
# Firewall
#
# deploy.sh publishes the blue/green containers directly on
# 8000/8001. Only SSH and HTTP should be reachable externally,
# otherwise those ports bypass Nginx entirely.
# ============================================================

echo
echo "Configuring firewall..."

$SUDO ufw allow OpenSSH
$SUDO ufw allow 80/tcp
$SUDO ufw --force enable

# ============================================================
# Nginx: base setup
# ============================================================

$SUDO rm -f /etc/nginx/sites-enabled/default
$SUDO systemctl enable nginx
$SUDO systemctl start nginx

# ============================================================
# GitHub SSH access
# ============================================================

echo
echo "Checking GitHub SSH access..."

if ! ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
        echo "Generating a deploy SSH key..."
        ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "${APP_NAME}-droplet"
    fi

    echo
    echo "ERROR: This droplet's SSH key is not authorized on GitHub."
    echo "Add the following public key as a Deploy Key on the repo"
    echo "(Settings > Deploy keys, read access is enough):"
    echo
    cat "$HOME/.ssh/id_ed25519.pub"
    echo
    echo "Then run this script again."
    exit 1
fi

echo "GitHub SSH access OK."

# ============================================================
# Clone repository
# ============================================================

echo
echo "Setting up application directory..."

$SUDO mkdir -p "$APP_DIR"
$SUDO chown -R "${RUN_USER}:${RUN_USER}" "$APP_DIR"

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

    $SUDO tee "$ENV_FILE" > /dev/null <<EOF
GROQ_API_KEY=
LLM_MODEL=llama-3.1-8b-instant
EOF

    $SUDO chmod 600 "$ENV_FILE"

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
# Build Docker image
# ============================================================

echo
echo "Building Docker image..."

docker build \
    -t "$DOCKER_IMAGE" \
    .

echo
echo "Docker image built successfully."

# ============================================================
# First deployment
#
# deploy.sh handles picking the environment (defaults to blue
# when nothing is running yet), starting the container, the
# health check, and the Nginx switch.
# ============================================================

echo
echo "Running first deployment..."

bash "$APP_DIR/deploy.sh" "$DOCKER_IMAGE"

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

docker ps \
    --filter "name=${APP_NAME}-" \
    --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
