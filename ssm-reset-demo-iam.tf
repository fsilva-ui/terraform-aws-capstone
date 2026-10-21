resource "aws_iam_role" "ssm_reset_demo" {
  name = "${var.project_name}-ssm-reset-demo"

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

resource "aws_iam_role_policy" "ssm_reset_demo" {
  name = "${var.project_name}-ssm-reset-demo-policy"
  role = aws_iam_role.ssm_reset_demo.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ec2:DescribeInstances",
          "ssm:DescribeInstanceInformation",
          "ssm:GetCommandInvocation",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations"
        ]

        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = "ssm:SendCommand"

        Resource = "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript"
      },
      {
        Effect = "Allow"
        Action = "ssm:SendCommand"

        Resource = "arn:aws:ec2:${var.aws_region}:088811745609:instance/*"

        Condition = {
          StringEquals = {
            "ssm:resourceTag/RecoveryManagedBy" = "SSMAutomation"
          }
        }
      }
    ]
  })
}