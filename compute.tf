data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}


resource "aws_instance" "nextcloud_dr" {
  ami           = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = "t3.small"
  subnet_id     = aws_subnet.public_a.id

  vpc_security_group_ids = [
    aws_security_group.public_app.id
  ]

  key_name             = aws_key_pair.capstone_nextcloud.key_name
  iam_instance_profile = aws_iam_instance_profile.nextcloud_dr.name

  associate_public_ip_address = true

  user_data = file("${path.module}/scripts/restore-nextcloud.sh")

  tags = {
    Name     = "${var.project_name}-nextcloud-dr"
    Workload = "Nextcloud"
  }
}