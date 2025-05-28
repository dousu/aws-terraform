# Get all VPCs in the current region
data "aws_vpcs" "all" {}

# Get existing default security groups to determine their IDs
data "aws_security_group" "default" {
  for_each = toset(data.aws_vpcs.all.ids)

  filter {
    name   = "group-name"
    values = ["default"]
  }

  filter {
    name   = "vpc-id"
    values = [each.value]
  }
}

# Import existing default security groups and manage them with no rules
import {
  for_each = data.aws_security_group.default
  to       = aws_default_security_group.default[each.key]
  id       = each.value.id
}

# Manage default security groups for each VPC with no rules
resource "aws_default_security_group" "default" {
  for_each = toset(data.aws_vpcs.all.ids)

  vpc_id = each.value

  # Explicitly define empty ingress and egress rules to remove all existing rules
  # This ensures compliance with AWS Security Hub EC2.2 requirement
  ingress = []
  egress  = []

  tags = merge(var.tags, {
    Name        = "default-${var.region}-${each.value}"
    Component   = "security"
    Purpose     = "aws-security-hub-ec2-2-compliance"
    Description = "Default security group with all rules removed for Security Hub compliance"
    Region      = var.region
  })
}