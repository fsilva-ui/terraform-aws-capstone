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