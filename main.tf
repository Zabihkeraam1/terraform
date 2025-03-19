provider "aws" {
  region     = "eu-north-1"
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}
terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket"
    key    = "eu-north-1/terraform.tfstate"
    region = "eu-north-1"
    dynamodb_table = "terraform-lock-table"
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

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_eip" "web_server_eip" {
  domain = "vpc"
}

resource "aws_eip_association" "web_server_eip_assoc" {
  instance_id   = aws_instance.web_server.id
  allocation_id = aws_eip.web_server_eip.id
}

# Generate an SSH key pair
resource "tls_private_key" "github_actions" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save the private key to a file (optional, for debugging)
resource "local_file" "private_key" {
  content  = tls_private_key.github_actions.private_key_pem
  filename = "id_rsa"
}

# Save the public key to a file (optional, for debugging)
resource "local_file" "public_key" {
  content  = tls_private_key.github_actions.public_key_openssh
  filename = "id_rsa.pub"
}

# Create an AWS key pair
resource "aws_key_pair" "github_actions" {
  key_name   = "github-actions-key"
  public_key = tls_private_key.github_actions.public_key_openssh
}
# Create an EC2 instance
resource "aws_instance" "web_server" {
  ami             = "ami-02e2af61198e99faf"
  instance_type   = "t3.micro"
  security_groups = [aws_security_group.web_server_sg.name]
  key_name      = aws_key_pair.github_actions.key_name
  tags = {
    Name = "web-server"
  }

}

# Introduce a delay before outputting the IP address
resource "null_resource" "delay" {
  depends_on = [aws_eip_association.web_server_eip_assoc]

  provisioner "local-exec" {
    command = "sleep 10"
  }
}

# Output the private key
output "private_key" {
  value     = tls_private_key.github_actions.private_key_pem
  sensitive = true  # Mark the output as sensitive to avoid logging
}

# Output the public IP of the EC2 instance
output "instance_public_ip" {
  value = aws_eip.web_server_eip.public_ip
}