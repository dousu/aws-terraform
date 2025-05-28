include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  config = yamldecode(file(find_in_parent_folders("common/config.yaml")))
}

terraform {
  source = "../../../modules/security"
}

# Generate region-specific provider (overrides root provider)
generate "region_provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"

  default_tags {
    tags = {
      Environment = "personal"
      Project     = "${local.config.project_name}"
      ManagedBy   = "Terragrunt"
      Region      = "eu-north-1"
    }
  }
}
EOF
}

inputs = {
  region = "eu-north-1"

  tags = merge(local.config.default_tags, {
    Component = "security"
    Purpose   = "aws-security-hub-ec2-2-compliance"
    Region    = "eu-north-1"
  })
}
