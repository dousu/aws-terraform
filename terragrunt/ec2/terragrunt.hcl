include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/ec2"
}

locals {
  config = yamldecode(file(find_in_parent_folders("common/config.yaml")))
}

inputs = {
  project_name = local.config.project_name
  environment  = "personal"
  region       = local.config.aws_region

  tags = merge(
    local.config.default_tags,
    {
      Component = "ec2"
    }
  )

  log_group_retention_days = 14
}
