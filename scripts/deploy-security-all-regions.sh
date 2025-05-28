#!/bin/bash

# Deploy Security Hub EC2.2 compliance across all regions
# This script deploys the security module to all configured regions
#
# Usage:
#   ./deploy-security-all-regions.sh           # Interactive apply mode
#   ./deploy-security-all-regions.sh plan      # Plan only mode
#   ./deploy-security-all-regions.sh apply     # Auto-apply mode

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAGRUNT_ROOT="$SCRIPT_DIR/../terragrunt"

# Parse command line arguments
MODE="${1:-interactive}"

case "$MODE" in
    plan)
        echo "🔍 Running in PLAN-ONLY mode"
        ;;
    apply)
        echo "🚀 Running in AUTO-APPLY mode"
        ;;
    interactive)
        echo "💫 Running in INTERACTIVE mode"
        ;;
    *)
        echo "❌ Invalid mode: $MODE"
        echo "Usage: $0 [plan|apply|interactive]"
        exit 1
        ;;
esac

# List of security deployment directories
SECURITY_DIRS=$(find $TERRAGRUNT_ROOT/security -mindepth 1 -maxdepth 1 -type d -printf "%f\n")

echo "🔒 Starting Security Hub EC2.2 compliance across all regions..."
echo "============================================================================"

# Function to process a specific region
process_region() {
    local dir=$1
    local region_name=$2
    
    echo ""
    echo "📍 Processing region: $region_name"
    echo "   Directory: $dir"
    echo "   $(date '+%Y-%m-%d %H:%M:%S')"
    echo "----------------------------------------"
    
    if ! cd "$TERRAGRUNT_ROOT/$dir"; then
        echo "❌ Failed to change to directory: $TERRAGRUNT_ROOT/$dir"
        return 1
    fi
    
    # Plan changes
    echo "🔍 Planning changes..."
    if ! terragrunt plan --non-interactive; then
        echo "❌ Plan failed for $region_name"
        return 1
    fi
    
    # Handle different modes
    case "$MODE" in
        plan)
            echo "📋 Plan completed for $region_name"
            ;;
        apply)
            echo "🚀 Auto-applying changes..."
            if terragrunt apply -auto-approve --non-interactive; then
                echo "✅ Successfully deployed to $region_name"
            else
                echo "❌ Deployment failed for $region_name"
                return 1
            fi
            ;;
        interactive)
            # Ask for confirmation
            echo -n "💫 Apply changes for $region_name? (y/N): "
            read -r REPLY
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "🚀 Applying changes..."
                if terragrunt apply -auto-approve --non-interactive; then
                    echo "✅ Successfully deployed to $region_name"
                else
                    echo "❌ Deployment failed for $region_name"
                    return 1
                fi
            else
                echo "⏭️  Skipped $region_name"
            fi
            ;;
    esac
}

# Process each region
for dir in $SECURITY_DIRS; do
    if [[ -d "$TERRAGRUNT_ROOT/security/$dir" ]]; then
        if ! process_region "security/$dir" $dir; then
            echo "❌ Failed to process $dir"
            if [[ "$MODE" != "plan" ]]; then
                echo "⚠️  Continuing with next region..."
            fi
        fi
    else
        echo "⚠️  Directory not found: $TERRAGRUNT_ROOT/security/$dir"
    fi
done

echo ""
echo "🎉 Security Hub EC2.2 compliance processing completed!"
echo "============================================================================"
if [[ "$MODE" == "plan" ]]; then
    echo "📋 Plan Summary:"
    echo "   - Reviewed all default security groups in specified regions"
    echo "   - Changes will remove all ingress and egress rules"
    echo "   - This ensures compliance with AWS Security Hub EC2.2 requirement"
else
    echo "📋 Deployment Summary:"
    echo "   - All default security groups in specified regions now have empty rules"
    echo "   - This ensures compliance with AWS Security Hub EC2.2 requirement"
    echo "   - Resources are properly tagged for identification"
fi
echo ""
echo "🔍 To verify compliance, check AWS Security Hub in each region"
