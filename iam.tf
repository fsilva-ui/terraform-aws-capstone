# IAM role used by the Nextcloud DR EC2 instance
resource "aws_iam_role" "nextcloud_dr" {
  name = "capstone-nextcloud-dr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "capstone-nextcloud-dr-role"
    Environment = "lab"
    Project     = "AWS Cloud Capstone"
  }
}

# Allow the Nextcloud DR instance to access only the DR backup bucket
resource "aws_iam_role_policy" "nextcloud_dr_s3" {
  name = "capstone-nextcloud-dr-s3"
  role = aws_iam_role.nextcloud_dr.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.dr_backup.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.dr_backup.arn}/*"
      }
    ]
  })
}

# Instance profile connects the IAM role to EC2
resource "aws_iam_instance_profile" "nextcloud_dr" {
  name = "capstone-nextcloud-dr-profile"
  role = aws_iam_role.nextcloud_dr.name
}

# Allow the Nextcloud DR instance to access the RDS master user secret
resource "aws_iam_role_policy" "nextcloud_dr_rds_secret" {
  name = "${var.project_name}-nextcloud-rds-secret"
  role = aws_iam_role.nextcloud_dr.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_db_instance.nextcloud.master_user_secret[0].secret_arn
      }
    ]
  })
}

# Additional deployment permissions for Terraform Cloud
resource "aws_iam_role_policy" "terraform_cloud_rds" {
  name = "TerraformCapstoneRDSDeploymentPolicy"
  role = "terraform-cloud-capstone"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ManageCapstoneRDS"
        Effect = "Allow"
        Action = "rds:*"

        Resource = [
          "arn:aws:rds:${var.aws_region}:088811745609:db:capstone-dr-*",
          "arn:aws:rds:${var.aws_region}:088811745609:pg:capstone-dr-*",
          "arn:aws:rds:${var.aws_region}:088811745609:subgrp:capstone-dr-*",
          "arn:aws:rds:${var.aws_region}:088811745609:snapshot:capstone-dr-*"
        ]
      },
      {
        Sid    = "ReadRDSConfiguration"
        Effect = "Allow"

        Action = [
          "rds:Describe*",
          "rds:ListTagsForResource"
        ]

        Resource = "*"
      },
      {
        Sid    = "CreateRDSManagedSecret"
        Effect = "Allow"

        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:TagResource",
          "secretsmanager:DescribeSecret"
        ]

        Resource = "arn:aws:secretsmanager:${var.aws_region}:088811745609:secret:rds!db-*"
      },
      {
        Sid      = "DescribeEncryptionKeys"
        Effect   = "Allow"
        Action   = "kms:DescribeKey"
        Resource = "arn:aws:kms:${var.aws_region}:088811745609:key/*"
      },
      {
        Sid    = "CreateRDSServiceLinkedRole"
        Effect = "Allow"
        Action = "iam:CreateServiceLinkedRole"

        Resource = "arn:aws:iam::088811745609:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"

        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "rds.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Attach the AmazonSSMManagedInstanceCore policy to the Nextcloud DR instance role
resource "aws_iam_role_policy_attachment" "nextcloud_dr_ssm_core" {
  role       = aws_iam_role.nextcloud_dr.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}