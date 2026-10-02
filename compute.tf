data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}


resource "aws_instance" "nextcloud_dr" {
  ami           = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_a.id

  vpc_security_group_ids = [
    aws_security_group.public_app.id
  ]

  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              dnf install -y httpd
              systemctl enable httpd
              systemctl start httpd

              cat <<'HTML' > /var/www/html/index.html
              <!DOCTYPE html>
              <html>
              <head>
                  <title>Nextcloud Disaster Recovery</title>
              </head>
              <body>
                  <h1>Nextcloud Disaster Recovery</h1>
                  <h2>Therapiezentrum Prietz</h2>
                  <p>Recovery server is operational.</p>
                  <p>Current stage: Infrastructure validation</p>
                  <p>Nextcloud deployment will follow in the next phase.</p>
                  <p>Infrastructure managed with Terraform.</p>
              </body>
              </html>
              HTML
              EOF

  tags = {
    Name     = "${var.project_name}-nextcloud-dr"
    Workload = "Nextcloud"
  }
}