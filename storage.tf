# Create S3 bucket for disaster recovery backup
resource "aws_s3_bucket" "dr_backup" {
  bucket_prefix = "capstone-dr-backup-"

  tags = {
    Name        = "capstone-dr-backup"
    Environment = "lab"
    Project     = "AWS Cloud Capstone"
  }
}

# Block public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "dr_backup" {
  bucket = aws_s3_bucket.dr_backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "dr_backup" {
  bucket = aws_s3_bucket.dr_backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for the S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "dr_backup" {
  bucket = aws_s3_bucket.dr_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}