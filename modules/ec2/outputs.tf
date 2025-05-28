output "eventbridge_rule_arn" {
  description = "EventBridge RuleのARN"
  value       = aws_cloudwatch_event_rule.ec2_launch.arn
}

output "ssm_document_name" {
  description = "SSM Automation DocumentのName"
  value       = aws_ssm_document.cloudwatch_agent_install.name
}

output "ssm_parameter_name" {
  description = "CloudWatch Agent設定のSSM Parameter名"
  value       = aws_ssm_parameter.cloudwatch_agent_config.name
}

output "log_group_name" {
  description = "CloudWatch Log GroupのName"
  value       = aws_cloudwatch_log_group.cloudwatch_agent_logs.name
}

output "eventbridge_role_arn" {
  description = "EventBridge用IAMロールのARN"
  value       = aws_iam_role.eventbridge_role.arn
}
