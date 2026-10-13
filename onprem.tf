# Simulated on-premises network
resource "aws_vpc" "onprem" {
  cidr_block           = "10.30.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-onprem-vpc"
  }
}

# Public subnet
resource "aws_subnet" "onprem_public" {
  vpc_id                  = aws_vpc.onprem.id
  cidr_block              = "10.30.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-onprem-public"
  }
}

# Internet gateway
resource "aws_internet_gateway" "onprem" {
  vpc_id = aws_vpc.onprem.id

  tags = {
    Name = "${var.project_name}-onprem-igw"
  }
}

# Route table
resource "aws_route_table" "onprem_public" {
  vpc_id = aws_vpc.onprem.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.onprem.id
  }

  tags = {
    Name = "${var.project_name}-onprem-public-rt"
  }
}

# Associate route table with subnet
resource "aws_route_table_association" "onprem_public" {
  subnet_id      = aws_subnet.onprem_public.id
  route_table_id = aws_route_table.onprem_public.id
}

# Security group
resource "aws_security_group" "onprem" {
  name        = "${var.project_name}-onprem-sg"
  description = "Simulated on-premises server access"
  vpc_id      = aws_vpc.onprem.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from administrator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip_cidr]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-onprem-sg"
  }
}

# Simulated on-premises server
resource "aws_instance" "onprem" {
  ami           = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.onprem_public.id

  vpc_security_group_ids = [
    aws_security_group.onprem.id
  ]

  key_name                    = aws_key_pair.capstone_nextcloud.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              dnf install -y httpd
              systemctl enable --now httpd

              cat > /var/www/html/index.html <<'HTML'
              <h1>Simulated On-Premises Environment</h1>
              <h2>Therapiezentrum Prietz</h2>
              <p>Primary server status: ONLINE</p>
              <p>Workload: Nextcloud (simulation)</p>
              HTML
              EOF

  tags = {
    Name = "${var.project_name}-onprem-server"
    Role = "Simulated-On-Premises"
  }

  lifecycle {
    ignore_changes = [
      ami,
      associate_public_ip_address
    ]
  }
}