include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules//ec2"
}

dependency "vpc" {
  config_path = "../vpc"
  
  mock_outputs = {
    vpc_id          = "vpc-12345678"
    private_subnets = ["subnet-12345678", "subnet-87654321"]
  }
}

inputs = {
  name = "web-personal"

  instance_type    = local.config.instance_type
  min_size         = local.config.min_size
  max_size         = local.config.max_size
  desired_capacity = local.config.desired_capacity

  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnets

  tags = {
    Environment = "personal"
  }
}

locals {
  config = yamldecode(file("${find_in_parent_folders("common/config.yaml")}"))
}
