resource "aws_ssm_document" "nextcloud_reset_demo" {
  name            = "capstone-nextcloud-reset-demo"
  document_type   = "Automation"
  document_format = "YAML"

  depends_on = [
    aws_iam_role_policy.ssm_reset_demo,
    aws_iam_role_policy_attachment.nextcloud_dr_ssm_core
  ]

  content = yamlencode({
    schemaVersion = "0.3"

    description = "Manually reset the Nextcloud demo database. Deletes all data in the nextcloud database."

    assumeRole = aws_iam_role.ssm_reset_demo.arn

    parameters = {
      InstanceId = {
        type           = "String"
        description    = "ID of the running Nextcloud recovery EC2 instance"
        allowedPattern = "^i-([0-9a-f]{8}|[0-9a-f]{17})$"
      }

      Confirmation = {
        type        = "String"
        description = "Enter RESET-NEXTCLOUD-DEMO to confirm deletion of the demo database contents"

        allowedValues = [
          "RESET-NEXTCLOUD-DEMO"
        ]
      }
    }

    mainSteps = [
      {
        name      = "CheckRecoveryInstance"
        action    = "aws:executeScript"
        onFailure = "Abort"

        inputs = {
          Runtime = "python3.11"
          Handler = "check_instance"

          InputPayload = {
            instance_id          = "{{InstanceId}}"
            region               = var.aws_region
            vpc_id               = aws_vpc.dr.id
            instance_profile_arn = aws_iam_instance_profile.nextcloud_dr.arn
          }

          Script = <<-PYTHON
            import boto3

            def check_instance(events, context):
                ec2 = boto3.client("ec2", region_name=events["region"])

                pages = ec2.get_paginator("describe_instances").paginate(
                    Filters=[
                        {
                            "Name": "vpc-id",
                            "Values": [events["vpc_id"]]
                        },
                        {
                            "Name": "tag:RecoveryManagedBy",
                            "Values": ["SSMAutomation"]
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

                instances = [
                    instance
                    for page in pages
                    for reservation in page["Reservations"]
                    for instance in reservation["Instances"]
                ]

                if len(instances) != 1:
                    raise RuntimeError(
                        "Reset requires exactly one recovery instance in the DR VPC."
                    )

                instance = instances[0]

                if instance["InstanceId"] != events["instance_id"]:
                    raise RuntimeError("The selected instance is not the recovery instance.")

                if instance["State"]["Name"] != "running":
                    raise RuntimeError("The recovery instance must be running.")

                profile = instance.get("IamInstanceProfile", {}).get("Arn")

                if profile != events["instance_profile_arn"]:
                    raise RuntimeError("Unexpected EC2 instance profile.")

                ssm = boto3.client("ssm", region_name=events["region"])

                result = ssm.describe_instance_information(
                    Filters=[
                        {
                            "Key": "InstanceIds",
                            "Values": [events["instance_id"]]
                        }
                    ]
                )

                nodes = result["InstanceInformationList"]

                if not nodes or nodes[0]["PingStatus"] != "Online":
                    raise RuntimeError(
                        "The recovery instance is not online in Systems Manager."
                    )

                return {"instance_id": events["instance_id"]}
          PYTHON
        }

        outputs = [
          {
            Name     = "InstanceId"
            Selector = "$.Payload.instance_id"
            Type     = "String"
          }
        ]
      },
      {
        name           = "ResetNextcloudDemo"
        action         = "aws:runCommand"
        onFailure      = "Abort"
        timeoutSeconds = 900
        isEnd          = true

        inputs = {
          DocumentName = "AWS-RunShellScript"

          InstanceIds = [
            "{{CheckRecoveryInstance.InstanceId}}"
          ]

          Parameters = {
            executionTimeout = ["600"]

            commands = [
              <<-SHELL
                set -eu

                aws s3 cp \
                  s3://${aws_s3_bucket.dr_backup.bucket}/scripts/reset-nextcloud-demo.sh \
                  /root/reset-nextcloud-demo.sh

                /bin/bash /root/reset-nextcloud-demo.sh \
                  "${aws_db_instance.nextcloud.address}" \
                  "${aws_db_instance.nextcloud.master_user_secret[0].secret_arn}" \
                  "${var.aws_region}" \
                  "{{Confirmation}}"
              SHELL
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name    = "capstone-nextcloud-reset-demo"
    Project = "AWS Cloud Capstone"
  }
}