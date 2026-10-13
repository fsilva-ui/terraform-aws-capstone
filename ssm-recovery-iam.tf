# IAM role assumed by the custom SSM Automation runbook

resource "aws_iam_role" "ssm_recovery" {
  name = "${var.project_name}-ssm-recovery"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ssm.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Permissions required to launch a new EC2 recovery instance

resource "aws_iam_role_policy" "ssm_recovery" {
  name = "${var.project_name}-ssm-recovery-policy"

  role = aws_iam_role.ssm_recovery.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ec2:RunInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:CreateTags"
        ]

        Resource = "*"
      },
      {
        Effect = "Allow"

        Action = "iam:PassRole"

        Resource = aws_iam_role.nextcloud_dr.arn

        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      }
    ]
  })
}