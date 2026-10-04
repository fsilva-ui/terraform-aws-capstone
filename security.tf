# Public Application Load Balancer
resource "aws_security_group" "public_alb" {
  name        = "${var.project_name}-public-alb-sg"
  description = "Security group for public-facing application load balancer"
  vpc_id      = aws_vpc.dr.id

  tags = {
    Name = "${var.project_name}-public-alb-sg"
  }
}

# Public-facing application tier
# Intended for services such as DR Nextcloud frontend
resource "aws_security_group" "public_app" {
  name        = "${var.project_name}-public-app-sg"
  description = "Security group for public-facing applications"
  vpc_id      = aws_vpc.dr.id

  tags = {
    Name = "${var.project_name}-public-app-sg"
  }
}

# Internal-only applications
# T-RENA and Prevention must never be direcctly Internet acessible
resource "aws_security_group" "internal_app" {
  name        = "${var.project_name}-internal-app-sg"
  description = "Security group for internal-only applications"
  vpc_id      = aws_vpc.dr.id

  tags = {
    Name = "${var.project_name}-internal-app-sg"
  }
}

# Database / data tier
resource "aws_security_group" "data" {
  name        = "${var.project_name}-data-sg"
  description = "Security group for private data services"
  vpc_id      = aws_vpc.dr.id

  tags = {
    Name = "${var.project_name}-data-sg"
  }
}

# Inbound rules for public-facing application load balancer
resource "aws_security_group_rule" "alb_http" {
  security_group_id = aws_security_group.public_alb.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]

  description = "Allow HTTP traffic from the internet"
}

resource "aws_security_group_rule" "alb_https" {
  security_group_id = aws_security_group.public_alb.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]

  description = "Allow HTTPS traffic from the internet"
}

# Inbound/Outbound rules for public-facing application tier
resource "aws_security_group_rule" "public_app_http" {
  security_group_id = aws_security_group.public_app.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]

  description = "Temporary direct HTTP access for DR lab validation"
}

resource "aws_security_group_rule" "public_app_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["92.211.149.84/32"]
  security_group_id = aws_security_group.public_app.id
  description       = "Temporary SSH access for Nextcloud DR administration"
}

resource "aws_security_group_rule" "public_app_egress" {
  security_group_id = aws_security_group.public_app.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]

  description = "Allow outbound traffic for public DR application workloads"
}
