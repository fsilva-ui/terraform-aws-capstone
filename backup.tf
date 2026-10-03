# Create an AMI from the EC2 instance for disaster recovery purposes
resource "aws_ami_from_instance" "nextcloud_dr" {
  name               = "nextcloud-dr-recovery-image"
  source_instance_id = aws_instance.nextcloud_dr.id

  tags = {
    Name        = "nextcloud-dr-recovery-image"
    Environment = "lab"
    Project     = "AWS Cloud Capstone"
    Purpose     = "Disaster Recovery"
  }
}

# Create a new EC2 instance from the AMI for disaster recovery testing
resource "aws_instance" "nextcloud_recovery" {
  ami                         = aws_ami_from_instance.nextcloud_dr.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.public_app.id]
  associate_public_ip_address = true

  tags = {
    Name        = "nextcloud-dr-recovery"
    Environment = "lab"
    Project     = "AWS Cloud Capstone"
    Purpose     = "Disaster Recovery Test"
  }
}