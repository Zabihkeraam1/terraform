provider "aws" {
  region     = "eu-north-1"
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

# Query the default VPC
data "aws_vpc" "default" {
  default = true
}
# Query the existing security group
data "aws_security_group" "existing_sg" {
  name = "web-server-sg"
}

# Query instances using the security group
data "aws_instances" "instances_using_sg" {
  filter {
    name   = "instance.group-id"
    values = [data.aws_security_group.existing_sg.id]
  }
}
# Detach security group from instances before deleting
resource "null_resource" "detach_sg" {
  count = length(data.aws_instances.instances_using_sg.ids)

  provisioner "local-exec" {
    environment = {
      AWS_ACCESS_KEY_ID     = var.AWS_ACCESS_KEY_ID
      AWS_SECRET_ACCESS_KEY = var.AWS_SECRET_ACCESS_KEY
      AWS_DEFAULT_REGION    = "eu-north-1"
    }

    command = <<EOT
      aws ec2 modify-instance-attribute \
        --instance-id ${element(data.aws_instances.instances_using_sg.ids, count.index)} \
        --groups sg-NEW_GROUP_ID \
        --region eu-north-1
    EOT
  }
}
resource "null_resource" "delete_existing_sg" {
  triggers = {
    sg_id = data.aws_security_group.existing_sg.id
  }

  provisioner "local-exec" {
    environment = {
      AWS_ACCESS_KEY_ID     = var.AWS_ACCESS_KEY_ID
      AWS_SECRET_ACCESS_KEY = var.AWS_SECRET_ACCESS_KEY
      AWS_DEFAULT_REGION    = "eu-north-1"
    }

    command = <<-EOT
      aws ec2 delete-security-group --group-id ${data.aws_security_group.existing_sg.id} --region eu-north-1
    EOT
  }
}
# Create a security group for the EC2 instance
resource "aws_security_group" "web_server_sg" {
  depends_on = [null_resource.delete_existing_sg]
  name        = "web-server-sg"
  description = "Allow HTTP, HTTPS, and SSH traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an EC2 instance
resource "aws_instance" "web_server" {
  ami             = "ami-02e2af61198e99faf" # Replace with your desired AMI ID
  instance_type   = "t3.micro"
  security_groups = [aws_security_group.web_server_sg.name]

  tags = {
    Name = "web-server"
  }

  # Install Docker, Nginx, and GitHub Actions runner on the instance
user_data = <<-EOF
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

            # Copy the Nginx configuration file
            sudo cp /tmp/test.conf /etc/nginx/conf.d/test.conf

            # Test the Nginx configuration and reload Nginx
            sudo nginx -t
            sudo systemctl reload nginx

            # Install GitHub Actions runner
            mkdir actions-runner && cd actions-runner
            curl -o actions-runner-linux-x64-2.309.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.309.0/actions-runner-linux-x64-2.309.0.tar.gz
            tar xzf ./actions-runner-linux-x64-2.309.0.tar.gz
            ./config.sh --url https://github.com/Zabihkeraam1/terraform --token BHOW73FPT3AQQIHB7KXUUVDH2AO7E
            ./run.sh
            EOF
}

# Generate the Nginx configuration file
resource "local_file" "nginx_config" {
  content = <<-EOL
            server {
                listen 80;

                server_name ${aws_instance.web_server.public_ip};
                location / {
                    proxy_pass http://localhost:5173;
                    proxy_set_header Host \$host;
                    proxy_set_header X-Real-IP \$remote_addr;
                    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                    proxy_set_header X-Forwarded-Proto \$scheme;
                }
            }
            EOL
  filename = "${path.module}/test.conf"
}

# Output the public IP of the EC2 instance
output "public_ip" {
  value = aws_instance.web_server.public_ip
}