output "default_security_groups" {
  description = "Map of VPC IDs to their default security group information"
  value = {
    for vpc_id, sg in aws_default_security_group.default : vpc_id => {
      id          = sg.id
      name        = sg.name
      description = sg.description
      vpc_id      = sg.vpc_id
      arn         = sg.arn
    }
  }
}

output "processed_vpcs" {
  description = "List of VPC IDs that had their default security group rules removed"
  value       = keys(aws_default_security_group.default)
}