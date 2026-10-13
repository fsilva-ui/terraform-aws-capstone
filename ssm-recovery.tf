# Custom SSM Automation runbook for Nextcloud Disaster Recovery

resource "aws_ssm_document" "nextcloud_recovery" {
  name            = "capstone-nextcloud-dr-recovery"
  document_type   = "Automation"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "0.3"

    description = "Create a new EC2 instance to restore Nextcloud from S3"

    assumeRole = aws_iam_role.ssm_recovery.arn

    mainSteps = [
      {
        name   = "CreateDRInstance"
        action = "aws:runInstances"

        inputs = {
          ImageId = data.aws_ssm_parameter.amazon_linux_2023.value

          InstanceType = "t3.small"

          SubnetId = aws_subnet.public_a.id

          SecurityGroupIds = [
            aws_security_group.public_app.id
          ]

          IamInstanceProfileName = aws_iam_instance_profile.nextcloud_dr.name

          KeyName = aws_key_pair.capstone_nextcloud.key_name

          MinInstanceCount = 1
          MaxInstanceCount = 1

          UserData = base64encode(<<-EOF
            #!/bin/bash
            set -euo pipefail

            aws s3 cp \
              s3://${aws_s3_bucket.dr_backup.bucket}/scripts/restore-nextcloud.sh \
              /root/restore-nextcloud.sh

            chmod +x /root/restore-nextcloud.sh

            /root/restore-nextcloud.sh
          EOF
          )
        }
      }
    ]
  })

  tags = {
    Name    = "capstone-nextcloud-dr-recovery"
    Project = "AWS Cloud Capstone"
  }
}