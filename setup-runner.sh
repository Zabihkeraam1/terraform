#!/bin/bash
mkdir -p /home/ubuntu/actions-runner && cd /home/ubuntu/actions-runner || { echo "Failed to create actions-runner directory"; exit 1; }
curl -o actions-runner-linux-x64-2.309.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.309.0/actions-runner-linux-x64-2.309.0.tar.gz || { echo "Failed to download GitHub Actions runner"; exit 1; }
tar xzf ./actions-runner-linux-x64-2.309.0.tar.gz || { echo "Failed to extract GitHub Actions runner"; exit 1; }

# Fix permissions
sudo chown -R ubuntu:ubuntu /home/ubuntu/actions-runner
sleep 10
cd /home/ubuntu/actions-runner
sudo chmod +x /home/ubuntu/actions-runner/config.sh
rm -f .runner .credentials
# Configure the runner automatically
sudo -u ubuntu ./config.sh --url https://github.com/Zabihkeraam1/terraform --token BHOW73EWLO2G43YAS6LIHLLH2LSZO --unattended
sleep 10

# Start the runner
./run.sh || { echo "Failed to start GitHub Actions runner"; exit 1; }

# Debugging: Print success message
echo "GitHub Actions runner setup completed successfully!"