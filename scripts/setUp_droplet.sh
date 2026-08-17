#!/usr/bin/env bash
set -euo pipefail

APP_REPO_URL="${1:?Usage: setUp_droplet.sh <git-repo-url> <app-path>}"
APP_PATH="${2:?Usage: setUp_droplet.sh <git-repo-url> <app-path>}"

echo "Updating packages..."
sudo apt-get update -y

echo "Installing git, curl, and nginx..."
sudo apt-get install -y git curl nginx

if ! command -v docker &> /dev/null; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sudo sh
fi

echo "Enabling Docker service..."
sudo systemctl enable docker
sudo systemctl start docker

echo "Disabling Nginx default site (avoids conflicting with the app's port-80 site)..."
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl enable nginx
sudo systemctl start nginx

echo "Adding $USER to docker group..."
sudo usermod -aG docker "$USER"

echo "Allowing $USER passwordless sudo (deploy.sh runs nginx/systemctl commands non-interactively over SSH)..."
SUDOERS_FILE="/etc/sudoers.d/${USER}-deploy"
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_FILE" > /dev/null
sudo chmod 440 "$SUDOERS_FILE"
sudo visudo -cf "$SUDOERS_FILE"

echo "Configuring firewall (deploy.sh publishes blue/green containers on 8000/8001 directly; only 22 and 80 should be reachable externally)..."
sudo apt-get install -y ufw
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw --force enable

if [ ! -d "$APP_PATH/.git" ]; then
  echo "Cloning repo into $APP_PATH..."
  git clone "$APP_REPO_URL" "$APP_PATH"
else
  echo "Repo already exists at $APP_PATH, skipping clone."
fi

echo "Droplet setup complete. Log out and back in for the docker group change to take effect."
