# AWS Terraform with Terragrunt

This repository contains Terraform modules and Terragrunt configurations for personal AWS infrastructure management.

## Directory Structure (Example)

```
.
├── root.hcl                # Root Terragrunt configuration
├── common/                 # Configuration files
│   └── config.yaml         # Project configuration settings
├── modules/               # Reusable Terraform modules
│   ├── vpc/              # VPC module
│   ├── ec2/              # EC2 module
│   └── rds/              # RDS module (placeholder)
└── terragrunt/           # Resource configurations
    ├── vpc/              # VPC configuration
    ├── ec2/              # EC2 configuration
    └── rds/              # RDS configuration (placeholder)
```

## Getting Started

### Prerequisites

- Terraform >= 1.0
- Terragrunt
- AWS CLI configured
- VS Code with dev container support (optional)

### Using Dev Container

1. Open this repository in VS Code
2. Reopen in container when prompted
3. The dev container will automatically install Terraform, Terragrunt, and AWS CLI

### Manual Setup

```bash
# Install Terraform
# Install Terragrunt
# Configure AWS CLI
aws configure
```

### AWS Authentication

```bash
# Using SSO
aws configure sso --use-device-code --profile default
```

## Format

Format Terraform and Terragrunt files:

```bash
# Format all Terraform files
terraform fmt -recursive modules/

# Format all Terragrunt files (from project root)
terragrunt hcl format --all
```

## Lint

Validate configuration syntax and best practices:

```bash
# Validate Terragrunt configurations and Terraform modules
cd terragrunt/security/ap-northeast-1 && terragrunt validate && cd - || cd -
# terragrunt validate --all

# Run tflint for additional checks (if available)
tflint --chdir=modules/security/ --disable-rule=terraform_required_version --disable-rule=terraform_required_providers
```

## Deploy

### Deploy Security Configuration

```bash
cd terragrunt/security/ap-northeast-1
terragrunt apply
```

### Deploy All Resources

```bash
cd terragrunt
terragrunt apply --all
```

### Destroy Resources

```bash
# Destroy all resources
cd terragrunt
terragrunt destroy --all

# Destroy specific resource
cd terragrunt/security/ap-northeast-1
terragrunt destroy
```

## Features

- **Simplified Configuration**: Single YAML configuration file for all settings
- **DRY Configuration**: Common settings shared via YAML files
- **Remote State**: S3 backend with DynamoDB locking
- **Dependency Management**: Automatic dependency resolution between resources
- **Consistent Tagging**: Automatic tagging across all resources
- **Module Reusability**: Shared modules across resources

## Configuration

### Project Configuration

All configuration settings are defined in `common/config.yaml`:

- AWS region and availability zones
- Networking configuration (VPC, subnets)
- Compute configuration (instance types, scaling)
- Database configuration
- Default tags

## Best Practices

- State files are stored in S3 with encryption enabled
- DynamoDB is used for state locking
- Dependencies are explicitly defined
- All resources are tagged consistently
- Modules are versioned and reusable
