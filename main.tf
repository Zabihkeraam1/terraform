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
# Create an EC2 instance
resource "aws_instance" "web_server" {
  ami             = "ami-02e2af61198e99faf"
  instance_type   = "t3.micro"
  security_groups = [aws_security_group.web_server_sg.name]
  user_data     = <<-EOF
                #cloud-config
                users:
                  - name: ubuntu
                    ssh-authorized-keys:
                      - ${file("~/.ssh/id_rsa.pub")}
                EOF
  tags = {
    Name = "web-server"
  }

}
# Output the public IP of the EC2 instance
# output "instance_public_ip" {
#   value = aws_instance.web_server.public_ip
# }
# Introduce a delay before outputting the IP address
resource "null_resource" "delay" {
  depends_on = [aws_eip_association.web_server_eip_assoc]

  provisioner "local-exec" {
    command = "sleep 10"
  }
}
output "instance_public_ip" {
  value = aws_eip.web_server_eip.public_ip
}