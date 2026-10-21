resource "aws_db_subnet_group" "nextcloud" {
  name        = "${var.project_name}-nextcloud-db"
  description = "Private subnets for the Nextcloud database"

  subnet_ids = [
    aws_subnet.data_a.id,
    aws_subnet.data_b.id
  ]

  tags = {
    Name = "${var.project_name}-nextcloud-db"
  }
}

resource "aws_db_instance" "nextcloud" {
  identifier = "${var.project_name}-nextcloud-db"

  engine         = "mariadb"
  engine_version = "10.11.19"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                     = "nextcloud"
  username                    = "ncadmin"
  manage_master_user_password = true

  db_subnet_group_name = aws_db_subnet_group.nextcloud.name
  parameter_group_name = aws_db_parameter_group.nextcloud.name

  vpc_security_group_ids = [
    aws_security_group.data.id
  ]

  availability_zone   = aws_subnet.public_a.availability_zone
  publicly_accessible = false
  multi_az            = false

  backup_retention_period = 7
  deletion_protection     = true
  skip_final_snapshot     = false

  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.project_name}-nextcloud-db"
  }
}

resource "aws_db_parameter_group" "nextcloud" {
  name        = "${var.project_name}-nextcloud-mariadb"
  family      = "mariadb10.11"
  description = "MariaDB settings for Nextcloud"

  parameter {
    name  = "tx_isolation"
    value = "READ-COMMITTED"
  }

  parameter {
    name  = "binlog_format"
    value = "ROW"
  }

  tags = {
    Name = "${var.project_name}-nextcloud-mariadb"
  }
}