#!/bin/bash
set -e

echo "=========================================="
echo "EKS Cluster Cleanup Script"
echo "=========================================="
echo ""

# Variables
REGION="ap-southeast-2"
CLUSTER_NAME="dev-eks-cluster"
ACCOUNT_ID="<DEV_ACCOUNT_ID>"  # <-- replace with your dev account ID

echo "Configuration:"
echo "  Region: $REGION"
echo "  Cluster: $CLUSTER_NAME"
echo "  Account: $ACCOUNT_ID"
echo ""

# Check if cluster exists
echo "Checking if cluster exists..."
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" &>/dev/null; then
    echo "✓ Cluster found: $CLUSTER_NAME"
    
    # List node groups
    echo ""
    echo "Checking for node groups..."
    NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$REGION" --query 'nodegroups[]' --output text)
    
    if [ -n "$NODE_GROUPS" ]; then
        echo "Found node groups:"
        for NG in $NODE_GROUPS; do
            echo "  - $NG"
            echo "    Deleting node group: $NG"
            aws eks delete-nodegroup \
                --cluster-name "$CLUSTER_NAME" \
                --nodegroup-name "$NG" \
                --region "$REGION"
        done
        
        # Wait for node groups to delete
        echo ""
        echo "Waiting for node groups to delete (this takes 5-10 minutes)..."
        for NG in $NODE_GROUPS; do
            echo "  Waiting for: $NG"
            aws eks wait nodegroup-deleted \
                --cluster-name "$CLUSTER_NAME" \
                --nodegroup-name "$NG" \
                --region "$REGION"
            echo "  ✓ Deleted: $NG"
        done
    else
        echo "No node groups found"
    fi
    
    # Delete cluster
    echo ""
    echo "Deleting EKS cluster: $CLUSTER_NAME"
    aws eks delete-cluster --name "$CLUSTER_NAME" --region "$REGION"
    
    echo "Waiting for cluster to delete (this takes 5-10 minutes)..."
    aws eks wait cluster-deleted --name "$CLUSTER_NAME" --region "$REGION"
    echo "✓ Cluster deleted"
    
else
    echo "⚠ Cluster not found: $CLUSTER_NAME"
fi

# Clean up orphaned resources
echo ""
echo "=========================================="
echo "Cleaning up orphaned resources..."
echo "=========================================="

# Delete node group IAM role
echo ""
echo "Checking for node IAM role..."
NODE_ROLE="${CLUSTER_NAME}-node-role"
if aws iam get-role --role-name "$NODE_ROLE" &>/dev/null; then
    echo "Found role: $NODE_ROLE"
    
    # Detach policies
    echo "  Detaching policies..."
    aws iam detach-role-policy --role-name "$NODE_ROLE" --policy-arn "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" 2>/dev/null || true
    aws iam detach-role-policy --role-name "$NODE_ROLE" --policy-arn "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" 2>/dev/null || true
    aws iam detach-role-policy --role-name "$NODE_ROLE" --policy-arn "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" 2>/dev/null || true
    
    # Delete role
    echo "  Deleting role..."
    aws iam delete-role --role-name "$NODE_ROLE"
    echo "  ✓ Deleted: $NODE_ROLE"
else
    echo "⚠ Role not found: $NODE_ROLE"
fi

# Delete cluster IAM role
echo ""
echo "Checking for cluster IAM role..."
CLUSTER_ROLE="${CLUSTER_NAME}-cluster-role"
if aws iam get-role --role-name "$CLUSTER_ROLE" &>/dev/null; then
    echo "Found role: $CLUSTER_ROLE"
    
    # Detach policies
    echo "  Detaching policies..."
    aws iam detach-role-policy --role-name "$CLUSTER_ROLE" --policy-arn "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" 2>/dev/null || true
    aws iam detach-role-policy --role-name "$CLUSTER_ROLE" --policy-arn "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController" 2>/dev/null || true
    
    # Delete role
    echo "  Deleting role..."
    aws iam delete-role --role-name "$CLUSTER_ROLE"
    echo "  ✓ Deleted: $CLUSTER_ROLE"
else
    echo "⚠ Role not found: $CLUSTER_ROLE"
fi

# Delete OIDC provider
echo ""
echo "Checking for OIDC provider..."
OIDC_PROVIDERS=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[*].Arn' --output text)
for OIDC_ARN in $OIDC_PROVIDERS; do
    if [[ "$OIDC_ARN" == *"oidc.eks.${REGION}.amazonaws.com"* ]]; then
        echo "Found OIDC provider: $OIDC_ARN"
        echo "  Deleting..."
        aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN"
        echo "  ✓ Deleted OIDC provider"
    fi
done

# Delete security groups (careful - only delete EKS-specific ones)
echo ""
echo "Checking for EKS security groups..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=dev-workload-vpc" --query 'Vpcs[0].VpcId' --output text --region "$REGION")

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    echo "Found VPC: $VPC_ID"
    
    # Find security groups with cluster name
    SG_IDS=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*${CLUSTER_NAME}*" \
        --query 'SecurityGroups[*].GroupId' \
        --output text \
        --region "$REGION")
    
    if [ -n "$SG_IDS" ]; then
        for SG_ID in $SG_IDS; do
            SG_NAME=$(aws ec2 describe-security-groups --group-ids "$SG_ID" --query 'SecurityGroups[0].GroupName' --output text --region "$REGION")
            echo "Found security group: $SG_NAME ($SG_ID)"
            
            # Remove all rules first
            echo "  Removing ingress rules..."
            aws ec2 describe-security-groups --group-ids "$SG_ID" --region "$REGION" \
                --query 'SecurityGroups[0].IpPermissions' --output json > /tmp/ingress_rules.json
            
            if [ -s /tmp/ingress_rules.json ] && [ "$(cat /tmp/ingress_rules.json)" != "[]" ]; then
                aws ec2 revoke-security-group-ingress \
                    --group-id "$SG_ID" \
                    --ip-permissions file:///tmp/ingress_rules.json \
                    --region "$REGION" 2>/dev/null || true
            fi
            
            echo "  Removing egress rules..."
            aws ec2 describe-security-groups --group-ids "$SG_ID" --region "$REGION" \
                --query 'SecurityGroups[0].IpPermissionsEgress' --output json > /tmp/egress_rules.json
            
            if [ -s /tmp/egress_rules.json ] && [ "$(cat /tmp/egress_rules.json)" != "[]" ]; then
                aws ec2 revoke-security-group-egress \
                    --group-id "$SG_ID" \
                    --ip-permissions file:///tmp/egress_rules.json \
                    --region "$REGION" 2>/dev/null || true
            fi
            
            # Delete security group
            echo "  Deleting security group..."
            aws ec2 delete-security-group --group-id "$SG_ID" --region "$REGION" 2>/dev/null || echo "  ⚠ Could not delete (may have dependencies)"
        done
    else
        echo "⚠ No EKS security groups found"
    fi
else
    echo "⚠ VPC not found"
fi

# Check for VPC endpoints
echo ""
echo "Checking for VPC endpoints..."
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    VPC_ENDPOINTS=$(aws ec2 describe-vpc-endpoints \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=dev-*-endpoint" \
        --query 'VpcEndpoints[*].VpcEndpointId' \
        --output text \
        --region "$REGION")
    
    if [ -n "$VPC_ENDPOINTS" ]; then
        for VPC_EP in $VPC_ENDPOINTS; do
            VPC_EP_NAME=$(aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$VPC_EP" --query 'VpcEndpoints[0].Tags[?Key==`Name`].Value' --output text --region "$REGION")
            echo "Found VPC endpoint: $VPC_EP_NAME ($VPC_EP)"
            echo "  Deleting..."
            aws ec2 delete-vpc-endpoints --vpc-endpoint-ids "$VPC_EP" --region "$REGION"
            echo "  ✓ Deleted: $VPC_EP"
        done
    else
        echo "⚠ No VPC endpoints found"
    fi
fi

echo ""
echo "=========================================="
echo "✓ Cleanup complete!"
echo "=========================================="
echo ""
echo "You can now run 'terraform destroy' or 'terraform apply' to recreate with clean state"
