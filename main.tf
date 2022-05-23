variable "AWS_ACCESS_KEY" {
  type = string
}
variable "AWS_SECRET_KEY" {
  type = string
}
provider "aws" {
  region     = "eu-central-1"
  access_key = var.AWS_ACCESS_KEY
  secret_key = var.AWS_SECRET_KEY
}
variable "vpc_cidr_block" {
  type = string
}
resource "aws_vpc" "terraform_demo_vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "terraform_demo_vpc"
  }
}
resource "aws_internet_gateway" "terraform_demo_ig" {
  vpc_id = aws_vpc.terraform_demo_vpc.id
  tags = {
    Name = "terraform_demo_ig"
  }
}
resource "aws_route_table" "terraform_demo_rt" {
  vpc_id = aws_vpc.terraform_demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform_demo_ig.id
  }

  tags = {
    Name = "terraform_demo_rt"
  }
}
variable "subnet_cidr_block" {
  type = string
}
resource "aws_subnet" "terraform_demo_subnet" {
  vpc_id            = aws_vpc.terraform_demo_vpc.id
  cidr_block        = var.subnet_cidr_block
  availability_zone = "eu-central-1a"

  tags = {
    Name = "terraform_demo_subnet"
  }
}
resource "aws_route_table_association" "terraform_demo_subnet_rta" {
  subnet_id      = aws_subnet.terraform_demo_subnet.id
  route_table_id = aws_route_table.terraform_demo_rt.id
}
variable "ingress_cidr_block" {
  description = "security group ingress cidr block"
  default     = "0.0.0.0/0"
  type        = string
}
resource "aws_security_group" "terraform_demo_sg" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.terraform_demo_vpc.id

  ingress {
    description = "https"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.ingress_cidr_block]
  }
  ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.ingress_cidr_block]
  }
  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ingress_cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "all"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform_demo_sg"
  }
}
resource "aws_network_interface" "terraform_demo_ni" {
  subnet_id       = aws_subnet.terraform_demo_subnet.id
  private_ips     = ["10.0.0.42"]
  security_groups = [aws_security_group.terraform_demo_sg.id]
}
resource "aws_eip" "terraform_demo_eip" {
  depends_on                = [aws_internet_gateway.terraform_demo_ig]
  vpc                       = true
  network_interface         = aws_network_interface.terraform_demo_ni.id
  associate_with_private_ip = "10.0.0.42"
}
output "eip" {
  value = aws_eip.terraform_demo_eip.public_ip
}
resource "aws_instance" "terraform_demo_instance" {
  ami               = "ami-015c25ad8763b2f11"
  instance_type     = "t3.nano"
  availability_zone = "eu-central-1a"
  key_name          = "terraform_demo_key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.terraform_demo_ni.id
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install apache2 -y
    sudo systemctl start apache2
    sudo bash -c "echo 'Hello Terraform' > /var/www/html/index.html"
  EOF

  tags = {
    Name = "terraform_demo_instance"
  }
}
output "instance" {
  value = aws_instance.terraform_demo_instance.private_ip
}
