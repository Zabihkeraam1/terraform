# user_data.tpl
#!/bin/bash
sudo apt update
sudo apt install -y docker.io nginx
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker
sudo systemctl restart docker
mkdir -p ~/.docker/cli-plugins
curl -sSL https://github.com/docker/buildx/releases/download/v0.10.0/buildx-v0.10.0.linux-amd64 -o ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx
sudo systemctl start nginx
sudo systemctl enable nginx

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
sudo nginx -t
sudo systemctl reload nginx

# Install GitHub Actions runner
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.309.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.309.0/actions-runner-linux-x64-2.309.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.309.0.tar.gz
./config.sh --url https://github.com/Zabihkeraam1/terraform --token BHOW73FPT3AQQIHB7KXUUVDH2AO7E
./run.sh