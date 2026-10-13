# Static public IP for the Nextcloud DR instance

resource "aws_eip" "nextcloud_dr" {
  domain = "vpc"

  tags = {
    Name = "capstone-nextcloud-dr-eip"
  }
}

resource "aws_eip_association" "nextcloud_dr" {
  instance_id   = aws_instance.nextcloud_dr.id
  allocation_id = aws_eip.nextcloud_dr.id
}