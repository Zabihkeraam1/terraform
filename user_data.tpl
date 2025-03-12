#!/bin/bash
set -e  # Stop the script if any command fails

# Update system and install required packages
sudo apt update -y
sudo apt install -y docker.io nginx curl jq tar unzip

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to Docker group
sudo usermod -aG docker $USER
newgrp docker  # This won't take effect in the script; user needs to relog

# Install Docker Buildx
mkdir -p ~/.docker/cli-plugins
curl -sSL https://github.com/docker/buildx/releases/download/v0.10.0/buildx-v0.10.0.linux-amd64 -o ~/.docker/cli-plugins/docker-buildx || { echo "Failed to download Docker Buildx"; exit 1; }
chmod +x ~/.docker/cli-plugins/docker-buildx

# Restart Docker to apply changes
sudo systemctl restart docker

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Get the instance's public IP
public_ip=$(curl -s ifconfig.me)

# Ensure the Nginx conf.d directory exists
sudo mkdir -p /etc/nginx/conf.d

# Create the Nginx configuration file
sudo tee /etc/nginx/conf.d/test.conf > /dev/null <<EOL
server {
    listen 80;
    server_name ${public_ip};

    location / {
        proxy_pass http://localhost:5173;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Test Nginx configuration and reload Nginx
sudo nginx -t || { echo "Nginx configuration test failed"; exit 1; }
sudo systemctl reload nginx || { echo "Failed to reload Nginx"; exit 1; }

# Create actions-runner directory and navigate into it
mkdir -p ~/actions-runner && cd ~/actions-runner || { echo "Failed to create actions-runner directory"; exit 1; }

# Download GitHub Actions runner
RUNNER_VERSION="2.309.0"
curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz || { echo "Failed to download GitHub Actions runner"; exit 1; }
tar xzf ./actions-runner-linux-x64.tar.gz || { echo "Failed to extract GitHub Actions runner"; exit 1; }

# Fetch a fresh GitHub runner token dynamically
GITHUB_ACCESS_TOKEN="YOUR_GITHUB_PERSONAL_ACCESS_TOKEN"  # Replace with a real token
GITHUB_REPO="Zabihkeraam1/terraform"

RUNNER_TOKEN=$(curl -s -X POST -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" \
    "https://api.github.com/repos/${GITHUB_REPO}/actions/runners/registration-token" | jq -r '.token')

if [[ -z "$RUNNER_TOKEN" ]]; then
    echo "Failed to fetch GitHub Actions runner token."
    exit 1
fi

# Configure the GitHub Actions runner
./config.sh --url https://github.com/${GITHUB_REPO} --token ${RUNNER_TOKEN} --unattended --replace || { echo "Failed to configure GitHub Actions runner"; exit 1; }

# Install runner as a service and start it
sudo ./svc.sh install
sudo ./svc.sh start

echo "GitHub Actions Runner setup complete!"
