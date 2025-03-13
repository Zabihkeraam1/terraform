#!/bin/bash

# Update and install dependencies
sudo apt update
sudo apt install -y docker.io nginx
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
sudo systemctl restart docker

# Install Docker Buildx
mkdir -p ~/.docker/cli-plugins
curl -sSL https://github.com/docker/buildx/releases/download/v0.10.0/buildx-v0.10.0.linux-amd64 -o ~/.docker/cli-plugins/docker-buildx || { echo "Failed to download Docker Buildx"; exit 1; }
chmod +x ~/.docker/cli-plugins/docker-buildx

# Start and enable Nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Ensure the Nginx conf.d directory exists
sudo mkdir -p /etc/nginx/conf.d

# Fetch the public IP dynamically
public_ip=$(curl -s http://checkip.amazonaws.com)

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

# Test the Nginx configuration and reload Nginx
sudo nginx -t || { echo "Nginx configuration test failed"; exit 1; }
sudo systemctl reload nginx || { echo "Failed to reload Nginx"; exit 1; }

# Install GitHub Actions runner
mkdir -p /home/ubuntu/actions-runner && cd /home/ubuntu/actions-runner || { echo "Failed to create actions-runner directory"; exit 1; }
curl -o actions-runner-linux-x64-2.309.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.309.0/actions-runner-linux-x64-2.309.0.tar.gz || { echo "Failed to download GitHub Actions runner"; exit 1; }
tar xzf ./actions-runner-linux-x64-2.309.0.tar.gz || { echo "Failed to extract GitHub Actions runner"; exit 1; }

# Fix permissions
sudo chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

# Configure the runner automatically
./config.sh --url https://github.com/Zabihkeraam1/terraform --token BHOW73DNGRUSDPQXUATJ3GTH2LAZO --unattended --name my-runner --labels self-hosted,linux --work _work || { echo "Failed to configure GitHub Actions runner"; exit 1; }

# Start the runner
./run.sh || { echo "Failed to start GitHub Actions runner"; exit 1; }

# Debugging: Print success message
echo "GitHub Actions runner setup completed successfully!"