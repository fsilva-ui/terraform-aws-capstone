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