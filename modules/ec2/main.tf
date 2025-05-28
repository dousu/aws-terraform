# Local values
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  default_cloudwatch_config = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "cwagent"
    }
    metrics = {
      namespace = "CWAgent"
      metrics_collected = {
        cpu = {
          measurement = [
            "cpu_usage_idle",
            "cpu_usage_iowait",
            "cpu_usage_user",
            "cpu_usage_system"
          ]
          metrics_collection_interval = 60
        }
        disk = {
          measurement                 = ["used_percent"]
          metrics_collection_interval = 60
          resources                   = ["*"]
        }
        diskio = {
          measurement                 = ["io_time"]
          metrics_collection_interval = 60
          resources                   = ["*"]
        }
        mem = {
          measurement                 = ["mem_used_percent"]
          metrics_collection_interval = 60
        }
        netstat = {
          measurement = [
            "tcp_established",
            "tcp_time_wait"
          ]
          metrics_collection_interval = 60
        }
        swap = {
          measurement                 = ["swap_used_percent"]
          metrics_collection_interval = 60
        }
      }
    }
  })
}

# EventBridge用IAMロールの信頼ポリシー
data "aws_iam_policy_document" "eventbridge_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# EventBridge用IAMロール
resource "aws_iam_role" "eventbridge_role" {
  name = "${local.name_prefix}-eventbridge-ssm-role"

  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json

  tags = var.tags
}

# EventBridge用IAMポリシードキュメント
data "aws_iam_policy_document" "eventbridge_ssm_policy" {
  statement {
    effect = "Allow"

    actions = [
      "ssm:StartAutomationExecution"
    ]

    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:automation-definition/${aws_ssm_document.cloudwatch_agent_install.name}:$DEFAULT"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      aws_iam_role.ssm_automation_role.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ssm.amazonaws.com"]
    }
  }
}

# EventBridge用IAMポリシー
resource "aws_iam_policy" "eventbridge_ssm_policy" {
  name        = "${local.name_prefix}-eventbridge-ssm-policy"
  description = "EventBridge が SSM Automation を実行するためのポリシー"

  policy = data.aws_iam_policy_document.eventbridge_ssm_policy.json

  tags = var.tags
}

# EventBridge用IAMロールにポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "eventbridge_ssm_attach" {
  role       = aws_iam_role.eventbridge_role.name
  policy_arn = aws_iam_policy.eventbridge_ssm_policy.arn
}

# SSM Automation実行用IAMロールの信頼ポリシー
data "aws_iam_policy_document" "ssm_automation_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# SSM Automation実行用IAMロール
resource "aws_iam_role" "ssm_automation_role" {
  name = "${local.name_prefix}-ssm-automation-role"

  assume_role_policy = data.aws_iam_policy_document.ssm_automation_assume_role.json

  tags = var.tags
}

# SSM Automation実行用IAMポリシードキュメント
data "aws_iam_policy_document" "ssm_automation_policy" {
  statement {
    effect = "Allow"

    actions = [
      "ssm:SendCommand",
      "ssm:ListCommands",
      "ssm:ListCommandInvocations",
      "ssm:DescribeInstanceInformation",
      "ssm:GetAutomationExecution",
      "ssm:DescribeAutomationExecutions",
      "ssm:DescribeAutomationStepExecutions",
      "ssm:StopAutomationExecution",
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInstances"
    ]

    resources = ["*"]
  }
}

# SSM Automation実行用IAMポリシー
resource "aws_iam_policy" "ssm_automation_policy" {
  name        = "${local.name_prefix}-ssm-automation-policy"
  description = "SSM Automation が EC2 インスタンスでコマンドを実行するためのポリシー"

  policy = data.aws_iam_policy_document.ssm_automation_policy.json

  tags = var.tags
}

# SSM Automation実行用IAMロールにポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "ssm_automation_attach" {
  role       = aws_iam_role.ssm_automation_role.name
  policy_arn = aws_iam_policy.ssm_automation_policy.arn
}

# SSM Parameter Store: CloudWatch Agent設定
resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name  = "/cloudwatch/agent/config"
  type  = "String"
  value = var.cloudwatch_agent_config != "" ? var.cloudwatch_agent_config : local.default_cloudwatch_config

  description = "CloudWatch Agent configuration for automatic installation"

  tags = var.tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "cloudwatch_agent_logs" {
  name              = "/aws/amazoncloudwatch-agent"
  retention_in_days = var.log_group_retention_days

  tags = var.tags
}

# SSM Automation Document
resource "aws_ssm_document" "cloudwatch_agent_install" {
  name            = "${local.name_prefix}-install-cloudwatch-agent"
  document_type   = "Automation"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "0.3"
    description   = "EC2インスタンスにCloudWatch Agentを自動インストール・設定するドキュメント"
    assumeRole    = "{{ AutomationAssumeRole }}"

    parameters = {
      InstanceId = {
        type        = "String"
        description = "CloudWatch AgentをインストールするインスタンスのID"
      }
      AutomationAssumeRole = {
        type        = "String"
        description = "Automation実行用のIAMロール"
        default     = ""
      }
    }

    mainSteps = [
      {
        name   = "checkInstanceStatus"
        action = "aws:waitForAwsResourceProperty"
        inputs = {
          Service          = "ec2"
          Api              = "DescribeInstanceStatus"
          InstanceIds      = ["{{ InstanceId }}"]
          PropertySelector = "$.InstanceStatuses[0].InstanceStatus.Status"
          DesiredValues    = ["ok"]
        }
        timeoutSeconds = 600
      },
      {
        name   = "installCloudWatchAgent"
        action = "aws:runCommand"
        inputs = {
          DocumentName = "AWS-ConfigureAWSPackage"
          InstanceIds  = ["{{ InstanceId }}"]
          Parameters = {
            action = "Install"
            name   = "AmazonCloudWatchAgent"
          }
        }
      },
      {
        name   = "startCloudWatchAgent"
        action = "aws:runCommand"
        inputs = {
          DocumentName = "AmazonCloudWatch-ManageAgent"
          InstanceIds  = ["{{ InstanceId }}"]
          Parameters = {
            action                        = "configure"
            mode                          = "ec2"
            optionalConfigurationLocation = aws_ssm_parameter.cloudwatch_agent_config.name
            optionalRestart               = "yes"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# EventBridge Rule: EC2インスタンス起動検知
resource "aws_cloudwatch_event_rule" "ec2_launch" {
  name        = "${local.name_prefix}-ec2-launch-rule"
  description = "EC2インスタンスの起動を検知するルール"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["running"]
    }
  })

  tags = var.tags
}

# EventBridge Target: SSM Automation実行
resource "aws_cloudwatch_event_target" "ssm_automation" {
  rule      = aws_cloudwatch_event_rule.ec2_launch.name
  target_id = "SSMAutomationTarget"
  arn       = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:automation-definition/${aws_ssm_document.cloudwatch_agent_install.name}:$DEFAULT"
  role_arn  = aws_iam_role.eventbridge_role.arn

  input_transformer {
    input_paths = {
      instance = "$.detail.instance-id"
    }
    input_template = "{\"InstanceId\":[\"<instance>\"],\"AutomationAssumeRole\":[\"${aws_iam_role.ssm_automation_role.arn}\"]}"
  }
}

# データソース
data "aws_caller_identity" "current" {}
