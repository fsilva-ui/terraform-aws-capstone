resource "aws_key_pair" "capstone_nextcloud" {
  key_name   = "capstone-nextcloud"
  public_key = var.ssh_public_key

  tags = {
    Name        = "capstone-nextcloud"
    Environment = "lab"
    Project     = "AWS Cloud Capstone"
  }
}