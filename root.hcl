locals {
  # Load configuration variables
  config = yamldecode(file("${find_in_parent_folders("common/config.yaml")}"))
}

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "${local.config.project_name}-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.config.aws_region
    dynamodb_table = "${local.config.project_name}-terraform-locks"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Generate an AWS provider block
generate "provider" {
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
  region = "${local.config.aws_region}"

  default_tags {
    tags = {
      Environment = "personal"
      Project     = "${local.config.project_name}"
      ManagedBy   = "Terragrunt"
    }
  }
}
EOF
}

# Generate common variables
generate "common_variables" {
  path      = "common_variables.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "personal"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "${local.config.project_name}"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "${local.config.aws_region}"
}
EOF
}

# Configure root level variables that all resources can inherit
inputs = merge(
  local.config,
  {
    environment = "personal"
  }
)
