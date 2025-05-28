output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.web.id
}

output "launch_template_id" {
  description = "The ID of the launch template"
  value       = aws_launch_template.web.id
}

output "autoscaling_group_arn" {
  description = "The ARN for this AutoScaling Group"
  value       = aws_autoscaling_group.web.arn
}

output "autoscaling_group_name" {
  description = "The name of the AutoScaling Group"
  value       = aws_autoscaling_group.web.name
}
