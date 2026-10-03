data "aws_ebs_volume" "nextcloud_dr" {
  most_recent = true

  filter {
    name   = "attachment.instance-id"
    values = [aws_instance.nextcloud_dr.id]
  }
}

resource "aws_ebs_snapshot" "nextcloud_dr" {
  volume_id = data.aws_ebs_volume.nextcloud_dr.id

  tags = {
    Name        = "nextcloud-dr-snapshot"
    Environment = "lab"
    Project     = "AWS Cloud Capstone"
    Purpose     = "Disaster Recovery"
  }
}