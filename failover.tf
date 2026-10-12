# IAM role used by EventBridge to start SSM Automation
resource "aws_iam_role" "eventbridge_ssm" {
  name = "${var.project_name}-eventbridge-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Permissions to start the SSM automation
resource "aws_iam_role_policy" "eventbridge_ssm" {
  name = "${var.project_name}-eventbridge-ssm-policy"
  role = aws_iam_role.eventbridge_ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:StartAutomationExecution"
        Resource = "arn:aws:ssm:${var.aws_region}::document/AWS-StartEC2Instance"
      },
      {
        Effect   = "Allow"
        Action   = "ec2:StartInstances"
        Resource = aws_instance.nextcloud_dr.arn
      }
    ]
  })
}

# Detect when the simulated on-premises EC2 stops
resource "aws_cloudwatch_event_rule" "onprem_stopped" {
  name = "${var.project_name}-onprem-stopped"

  event_pattern = jsonencode({
    source        = ["aws.ec2"]
    "detail-type" = ["EC2 Instance State-change Notification"]
    detail = {
      "instance-id" = [aws_instance.onprem.id]
      state         = ["stopped"]
    }
  })
}

# Run the AWS-managed SSM automation
resource "aws_cloudwatch_event_target" "start_dr" {
  rule     = aws_cloudwatch_event_rule.onprem_stopped.name
  arn      = "arn:aws:ssm:${var.aws_region}::automation-definition/AWS-StartEC2Instance"
  role_arn = aws_iam_role.eventbridge_ssm.arn

  input = jsonencode({
    InstanceId = [aws_instance.nextcloud_dr.id]
  })
}