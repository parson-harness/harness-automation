#!/usr/bin/env bash
# Show IAM permissions assigned to delegate roles
# Useful for debugging IAM issues in customer POV accounts
# Usage: ./scripts/show-iam-permissions.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_DIR="$(dirname "$SCRIPT_DIR")"

cd "$AWS_DIR"

# Get cluster name from terraform output or use default
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "harness-eks-parson")

echo "=============================================="
echo "IAM Permissions for Harness Delegate Roles"
echo "Cluster: $CLUSTER_NAME"
echo "=============================================="
echo ""

# IRSA Role
IRSA_ROLE_NAME="${CLUSTER_NAME}-harness-delegate-ng-harness-delegate-irsa"
echo ">>> IRSA Role: $IRSA_ROLE_NAME"
echo "----------------------------------------------"

# Get IRSA role trust policy
echo ""
echo "[Trust Policy]"
aws iam get-role --role-name "$IRSA_ROLE_NAME" --query 'Role.AssumeRolePolicyDocument' --output json 2>/dev/null | jq '.' || echo "  (role not found)"

# Get attached policies
echo ""
echo "[Attached Policies]"
ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$IRSA_ROLE_NAME" --query 'AttachedPolicies[*].PolicyArn' --output text 2>/dev/null || echo "")
if [ -n "$ATTACHED_POLICIES" ]; then
  for POLICY_ARN in $ATTACHED_POLICIES; do
    echo ""
    echo "Policy: $POLICY_ARN"
    VERSION_ID=$(aws iam get-policy --policy-arn "$POLICY_ARN" --query 'Policy.DefaultVersionId' --output text)
    aws iam get-policy-version --policy-arn "$POLICY_ARN" --version-id "$VERSION_ID" --query 'PolicyVersion.Document' --output json | jq '.'
  done
else
  echo "  (none)"
fi

echo ""
echo "=============================================="

# EKS Node Group Role
echo ""
echo ">>> EKS Node Group Custom Policy"
echo "----------------------------------------------"

# Find the node policy by prefix
NODE_POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?starts_with(PolicyName, 'eks-${CLUSTER_NAME}-describe-regions')].Arn | [0]" --output text 2>/dev/null || echo "")

if [ -n "$NODE_POLICY_ARN" ] && [ "$NODE_POLICY_ARN" != "None" ]; then
  echo "Policy: $NODE_POLICY_ARN"
  VERSION_ID=$(aws iam get-policy --policy-arn "$NODE_POLICY_ARN" --query 'Policy.DefaultVersionId' --output text)
  aws iam get-policy-version --policy-arn "$NODE_POLICY_ARN" --version-id "$VERSION_ID" --query 'PolicyVersion.Document' --output json | jq '.'
else
  echo "  (node policy not found)"
fi

echo ""
echo "=============================================="
echo "Done."
