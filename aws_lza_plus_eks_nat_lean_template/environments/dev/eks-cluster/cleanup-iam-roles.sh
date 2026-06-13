#!/bin/bash
# cleanup-iam-roles.sh

CLUSTER_NAME="dev-eks-cluster"
REGION="ap-southeast-2"

echo "========================================="
echo "Cleaning up EKS IAM Roles"
echo "========================================="

# Function to detach all policies and delete role
cleanup_role() {
  ROLE_NAME=$1
  echo ""
  echo "Cleaning up role: $ROLE_NAME"
  
  # Check if role exists
  if ! aws iam get-role --role-name $ROLE_NAME 2>/dev/null; then
    echo "  ✅ Role doesn't exist, skipping"
    return
  fi
  
  # Detach managed policies
  echo "  Detaching managed policies..."
  aws iam list-attached-role-policies --role-name $ROLE_NAME --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null | tr '\t' '\n' | while read POLICY_ARN; do
    if [ -n "$POLICY_ARN" ]; then
      echo "    - Detaching: $POLICY_ARN"
      aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn $POLICY_ARN 2>/dev/null || true
    fi
  done
  
  # Delete inline policies
  echo "  Deleting inline policies..."
  aws iam list-role-policies --role-name $ROLE_NAME --query 'PolicyNames[]' --output text 2>/dev/null | tr '\t' '\n' | while read POLICY_NAME; do
    if [ -n "$POLICY_NAME" ]; then
      echo "    - Deleting: $POLICY_NAME"
      aws iam delete-role-policy --role-name $ROLE_NAME --policy-name $POLICY_NAME 2>/dev/null || true
    fi
  done
  
  # Delete instance profiles
  echo "  Removing from instance profiles..."
  aws iam list-instance-profiles-for-role --role-name $ROLE_NAME --query 'InstanceProfiles[].InstanceProfileName' --output text 2>/dev/null | tr '\t' '\n' | while read PROFILE_NAME; do
    if [ -n "$PROFILE_NAME" ]; then
      echo "    - Removing from profile: $PROFILE_NAME"
      aws iam remove-role-from-instance-profile --instance-profile-name $PROFILE_NAME --role-name $ROLE_NAME 2>/dev/null || true
      aws iam delete-instance-profile --instance-profile-name $PROFILE_NAME 2>/dev/null || true
    fi
  done
  
  # Delete the role
  echo "  Deleting role..."
  aws iam delete-role --role-name $ROLE_NAME 2>/dev/null && echo "  ✅ Role deleted" || echo "  ⚠️  Failed to delete role"
}

# Clean up cluster role
cleanup_role "${CLUSTER_NAME}-cluster-role"

# Clean up node role
cleanup_role "${CLUSTER_NAME}-node-role"

echo ""
echo "========================================="
echo "✅ IAM cleanup complete!"
echo "========================================="
