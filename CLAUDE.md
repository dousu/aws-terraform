# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a **Terragrunt-managed Terraform codebase** for personal AWS infrastructure. The architecture uses a simplified configuration pattern:

- **Root** (`root.hcl`): Global configuration with S3 remote state and provider generation
- **Common** (`common/`): YAML-based configuration (single config.yaml file)
- **Modules** (`modules/`): Reusable Terraform modules (vpc, ec2, etc.)
- **Resources** (`terragrunt/`): Resource-specific deployments (vpc, ec2, rds)

## Key Configuration Pattern

### Root Configuration Features
- Single YAML configuration loading using `find_in_parent_folders("common/config.yaml")`
- Auto-generated S3 backend with DynamoDB locking
- Consistent tagging across all resources via provider configuration
- Provider and common variables auto-generation

### Resource Dependencies
Resources declare dependencies explicitly:
```hcl
dependency "vpc" {
  config_path = "../vpc"
}
inputs = {
  vpc_id = dependency.vpc.outputs.vpc_id
}
```

## Common Commands

### Format and Lint
```bash
# Format all files
terraform fmt -recursive modules/
terragrunt hcl format

# Validate configurations
cd terragrunt/vpc && terragrunt validate
cd terragrunt/ec2 && terragrunt validate
```

### Deploy
```bash
# Single resource
cd terragrunt/vpc && terragrunt apply

# All resources (respects dependencies)
cd terragrunt && terragrunt run-all apply

# Destroy all resources
cd terragrunt && terragrunt run-all destroy
```

## Development Patterns

### Adding New Resources
1. Create module in `modules/{resource}/` with standard Terraform structure
2. Create `terragrunt/{resource}/terragrunt.hcl` configuration
3. Define dependencies using `dependency` blocks for resource relationships
4. Configure `locals.config` using `find_in_parent_folders("common/config.yaml")`

### Configuration System
Single configuration file approach:
1. `common/config.yaml` - all project settings (networking, compute, database, tags)
2. Resource-level `inputs` - resource-specific customization

## Important Notes

- Unified state management: Single S3 bucket and DynamoDB table for personal infrastructure
- Backend generation: Terragrunt auto-generates backend configuration
- Dependency order: VPC → EC2/RDS pattern with explicit dependency declarations
- Consistent tagging: Applied automatically via root provider configuration
- Root file naming: Use `root.hcl` instead of `terragrunt.hcl` to avoid anti-pattern warnings

## Code Style Rules

- ファイルの最後は改行で終了する
- 日本語を書く場合は句読点に`,`と`.`を使用すること
- READMEにはformat, lint, deployの項目を用意すること
