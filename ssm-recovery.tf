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
        name      = "CheckExistingDR"
        action    = "aws:executeScript"
        onFailure = "Abort"

        inputs = {
          Runtime = "python3.11"
          Handler = "check_instances"

          InputPayload = {
            region    = var.aws_region
            subnet_id = aws_subnet.public_a.id
          }

          Script = <<-PYTHON
            import boto3

            def check_instances(events, context):
                ec2 = boto3.client("ec2", region_name=events["region"])

                pages = ec2.get_paginator("describe_instances").paginate(
                    Filters=[
                        {
                            "Name": "tag:RecoveryManagedBy",
                            "Values": ["SSMAutomation"]
                        },
                        {
                            "Name": "subnet-id",
                            "Values": [events["subnet_id"]]
                        },
                        {
                            "Name": "instance-state-name",
                            "Values": [
                                "pending", "running", "stopping",
                                "stopped", "shutting-down"
                            ]
                        }
                    ]
                )

                for page in pages:
                    for reservation in page["Reservations"]:
                        if reservation["Instances"]:
                            return {"exists": True}

                return {"exists": False}
          PYTHON
        }

        outputs = [
          {
            Name     = "Exists"
            Selector = "$.Payload.exists"
            Type     = "Boolean"
          }
        ]
      },
      {
        name   = "DecideRecovery"
        action = "aws:branch"

        inputs = {
          Choices = [
            {
              Variable      = "{{CheckExistingDR.Exists}}"
              BooleanEquals = true
              NextStep      = "RecoveryAlreadyExists"
            }
          ]

          Default = "CreateDRInstance"
        }
      },
      {
        name   = "RecoveryAlreadyExists"
        action = "aws:executeScript"
        isEnd  = true

        inputs = {
          Runtime = "python3.11"
          Handler = "finish"

          Script = <<-PYTHON
            def finish(events, context):
                return {
                    "message": "A recovery instance already exists. No new instance was created."
                }
          PYTHON
        }
      },
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

          TagSpecifications = [
            {
              ResourceType = "instance"

              Tags = [
                {
                  Key   = "Name"
                  Value = "capstone-nextcloud-auto-recovery"
                },
                {
                  Key   = "RecoveryManagedBy"
                  Value = "SSMAutomation"
                }
              ]
            }
          ]

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