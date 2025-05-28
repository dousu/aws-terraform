include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules//vpc"
}

inputs = {
  name = "vpc-personal"
  cidr = local.config.vpc_cidr
  azs  = local.config.availability_zones

  public_subnets  = local.config.public_subnet_cidrs
  private_subnets = local.config.private_subnet_cidrs

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Environment = "personal"
  }
}

locals {
  config = yamldecode(file("${find_in_parent_folders("common/config.yaml")}"))
}