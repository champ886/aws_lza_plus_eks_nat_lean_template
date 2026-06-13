#!/bin/bash
# nuclear-cleanup.sh - Complete EKS cleanup

set -e

CLUSTER_NAME="dev-eks-cluster"
REGION="ap-southeast-2"
ACCOUNT_ID="<DEV_ACCOUNT_ID>"  # <-- replace with your dev account ID

echo "========================================="
echo "NUCLEAR CLEANUP - Complete EKS Removal"
echo "========================================="

# ────────────────────────────────────────────────────────────────────────────
# 1. EKS Resources
# ────────────────────────────────────────────────────────────────────────────
echo ""
echo "Step 1: Deleting EKS resources..."

# Delete node groups
for NG in $(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query 'nodegroups[]' --output text 2>/dev/null); do
  echo "  Deleting node group: $NG"
  aws eks delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NG --region $REGION 2>/dev/null || true
done

# Wait for node groups to delete
echo "  Waiting for node groups to delete..."
sleep 30

# Delete cluster
echo "  Deleting cluster: $CLUSTER_NAME"
aws eks delete-cluster --name $CLUSTER_NAME --region $REGION 2>/dev/null || echo "  Cluster already deleted"

# Wait for cluster deletion
echo "  Waiting for cluster deletion (this takes 10-15 minutes)..."
aws eks wait cluster-deleted --name $CLUSTER_NAME --region $REGION 2>/dev/null || echo "  Cluster already gone"

# ────────────────────────────────────────────────────────────────────────────
# 2. IAM Roles
# ────────────────────────────────────────────────────────────────────────────
echo ""
echo "Step 2: Deleting IAM roles..."

cleanup_role() {
  ROLE_NAME=$1
  echo "  Processing role: $ROLE_NAME"
  
  if ! aws iam get-role --role-name $ROLE_NAME 2>/dev/null >/dev/null; then
    echo "    Role doesn't exist, skipping"
    return
  fi
  
  # Detach managed policies
  aws iam list-attached-role-policies --role-name $ROLE_NAME --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null | tr '\t' '\n' | while read ARN; do
    [ -n "$ARN" ] && aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn $ARN 2>/dev/null || true
  done
  
  # Delete inline policies
  aws iam list-role-policies --role-name $ROLE_NAME --query 'PolicyNames[]' --output text 2>/dev/null | tr '\t' '\n' | while read PNAME; do
    [ -n "$PNAME" ] && aws iam delete-role-policy --role-name $ROLE_NAME --policy-name $PNAME 2>/dev/null || true
  done
  
  # Remove from instance profiles
  aws iam list-instance-profiles-for-role --role-name $ROLE_NAME --query 'InstanceProfiles[].InstanceProfileName' --output text 2>/dev/null | tr '\t' '\n' | while read PROF; do
    [ -n "$PROF" ] && aws iam remove-role-from-instance-profile --instance-profile-name $PROF --role-name $ROLE_NAME 2>/dev/null || true
    [ -n "$PROF" ] && aws iam delete-instance-profile --instance-profile-name $PROF 2>/dev/null || true
  done
  
  # Delete role
  aws iam delete-role --role-name $ROLE_NAME 2>/dev/null && echo "    ✅ Deleted" || echo "    ⚠️  Failed"
}

cleanup_role "${CLUSTER_NAME}-cluster-role"
cleanup_role "${CLUSTER_NAME}-node-role"

# ────────────────────────────────────────────────────────────────────────────
# 3. OIDC Providers
# ────────────────────────────────────────────────────────────────────────────
echo ""
echo "Step 3: Deleting OIDC providers..."

aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, 'oidc.eks.$REGION')].Arn" --output text | tr '\t' '\n' | while read ARN; do
  if [ -n "$ARN" ]; then
    echo "  Deleting OIDC provider: $ARN"
    aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$ARN" 2>/dev/null || true
  fi
done

# ────────────────────────────────────────────────────────────────────────────
# 4. Security Groups
# ────────────────────────────────────────────────────────────────────────────
echo ""
echo "Step 4: Deleting security groups..."
sleep 60  # Wait for ENIs to detach

aws ec2 describe-security-groups --region $REGION --filters "Name=tag:Name,Values=${CLUSTER_NAME}*" --query 'SecurityGroups[].GroupId' --output text | tr '\t' '\n' | while read SG_ID; do
  if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
    echo "  Deleting security group: $SG_ID"
    
    # Revoke all rules first
    aws ec2 describe-security-groups --group-ids $SG_ID --region $REGION --query 'SecurityGroups[0].IpPermissions' --output json > /tmp/sg-ingress-$SG_ID.json 2>/dev/null
    if [ -s /tmp/sg-ingress-$SG_ID.json ] && [ "$(cat /tmp/sg-ingress-$SG_ID.json)" != "[]" ]; then
      aws ec2 revoke-security-group-ingress --group-id $SG_ID --ip-permissions file:///tmp/sg-ingress-$SG_ID.json --region $REGION 2>/dev/null || true
    fi
    
    aws ec2 describe-security-groups --group-ids $SG_ID --region $REGION --query 'SecurityGroups[0].IpPermissionsEgress' --output json > /tmp/sg-egress-$SG_ID.json 2>/dev/null
    if [ -s /tmp/sg-egress-$SG_ID.json ] && [ "$(cat /tmp/sg-egress-$SG_ID.json)" != "[]" ]; then
      aws ec2 revoke-security-group-egress --group-id $SG_ID --ip-permissions file:///tmp/sg-egress-$SG_ID.json --region $REGION 2>/dev/null || true
    fi
    
    # Delete SG
    aws ec2 delete-security-group --group-id $SG_ID --region $REGION 2>/dev/null || echo "    Skipped (may be default or in use)"
  fi
done

# ────────────────────────────────────────────────────────────────────────────
# 5. Terraform State
# ────────────────────────────────────────────────────────────────────────────
echo ""
echo "Step 5: Cleaning Terraform state..."

aws s3 rm s3://<YOUR_STATE_BUCKET_NAME>/aws-lza/dev/eks-cluster/terraform.tfstate 2>/dev/null || true
aws s3 rm s3://<YOUR_STATE_BUCKET_NAME>/aws-lza/dev/eks-cluster/terraform.tfstate.backup 2>/dev/null || true

# Delete all DynamoDB entries
aws dynamodb scan --table-name tf-locks --region $REGION --filter-expression "contains(LockID, :state)" --expression-attribute-values '{":state":{"S":"eks-cluster"}}' --output json | jq -r '.Items[].LockID.S' | while read LOCK_ID; do
  echo "  Deleting DynamoDB entry: $LOCK_ID"
  aws dynamodb delete-item --table-name tf-locks --key "{\"LockID\":{\"S\":\"$LOCK_ID\"}}" --region $REGION
done

# ────────────────────────────────────────────────────────────────────────────
# 6. Verify
# ────────────────────────────────────────────────────────────────────────────
echo ""
echo "========================================="
echo "Verification"
echo "========================================="

echo "Cluster: $(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION 2>&1 | grep -q ResourceNotFoundException && echo '✅ Gone' || echo '❌ Still exists')"
echo "Cluster role: $(aws iam get-role --role-name ${CLUSTER_NAME}-cluster-role 2>&1 | grep -q NoSuchEntity && echo '✅ Gone' || echo '❌ Still exists')"
echo "Node role: $(aws iam get-role --role-name ${CLUSTER_NAME}-node-role 2>&1 | grep -q NoSuchEntity && echo '✅ Gone' || echo '❌ Still exists')"
echo "State file: $(aws s3 ls s3://<YOUR_STATE_BUCKET_NAME>/aws-lza/dev/eks-cluster/ 2>&1 | grep -q 'terraform.tfstate' && echo '❌ Still exists' || echo '✅ Gone')"

echo ""
echo "========================================="
echo "✅ Nuclear cleanup complete!"
echo "========================================="
echo ""
echo "Waiting 90 seconds for AWS consistency..."
sleep 90

echo ""
echo "Ready for fresh deployment!"
