#!/bin/bash

REGION="ap-southeast-2"
CLUSTER_NAME="dev-eks-cluster"

echo "=========================================="
echo "1. CHECK NODE GROUP STATUS & HEALTH"
echo "=========================================="
aws eks describe-nodegroup \
  --cluster-name "$CLUSTER_NAME" \
  --nodegroup-name "${CLUSTER_NAME}-system-nodes" \
  --region "$REGION" \
  --query 'nodegroup.{Status: status, Health: health, ScalingConfig: scalingConfig}' \
  --output json 2>/dev/null || echo "Node group not found"

echo ""
echo "=========================================="
echo "2. CHECK EC2 INSTANCES LAUNCHED BY NODE GROUP"
echo "=========================================="
aws ec2 describe-instances \
  --filters \
    "Name=tag:aws:eks:cluster-name,Values=${CLUSTER_NAME}" \
    "Name=instance-state-name,Values=running,pending,stopped" \
  --region "$REGION" \
  --query 'Reservations[*].Instances[*].{ID: InstanceId, State: State.Name, Subnet: SubnetId, SG: SecurityGroups[*].GroupId, PrivateIP: PrivateIpAddress}' \
  --output json

echo ""
echo "=========================================="
echo "3. CHECK SUBNETS NODES ARE LAUNCHING INTO"
echo "=========================================="
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters \
    "Name=tag:aws:eks:cluster-name,Values=${CLUSTER_NAME}" \
    "Name=instance-state-name,Values=running,pending" \
  --region "$REGION" \
  --query 'Reservations[*].Instances[*].SubnetId' \
  --output text)

for SUBNET in $INSTANCE_IDS; do
  echo "Subnet: $SUBNET"
  aws ec2 describe-subnets --subnet-ids "$SUBNET" --region "$REGION" \
    --query 'Subnets[0].{Name: Tags[?Key==`Name`].Value|[0], RouteTable: "check separately", CIDR: CidrBlock, AZ: AvailabilityZone}' \
    --output json
done

echo ""
echo "=========================================="
echo "4. CHECK ROUTE TABLES FOR PRIVATE SUBNETS"
echo "=========================================="
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "VPC ID: $VPC_ID"

aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*private*" \
  --region "$REGION" \
  --query 'RouteTables[*].{Name: Tags[?Key==`Name`].Value|[0], Routes: Routes[*].{Dest: DestinationCidrBlock, Target: GatewayId || NatGatewayId || VpcPeeringConnectionId || TransitGatewayId}}' \
  --output json

echo ""
echo "=========================================="
echo "5. CHECK SECURITY GROUPS ON NODES"
echo "=========================================="
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*${CLUSTER_NAME}*" \
  --region "$REGION" \
  --query 'SecurityGroups[*].{Name: GroupName, ID: GroupId, Ingress: IpPermissions, Egress: IpPermissionsEgress}' \
  --output json

echo ""
echo "=========================================="
echo "6. CHECK CLOUDWATCH LOGS FOR NODE ERRORS"
echo "=========================================="
aws logs filter-log-events \
  --log-group-name "/aws/eks/${CLUSTER_NAME}/cluster" \
  --filter-pattern "NodeCreationFailure OR failed OR error" \
  --start-time $(date -d '1 hour ago' +%s000) \
  --region "$REGION" \
  --query 'events[*].message' \
  --output text 2>/dev/null | head -30 || echo "No logs found or log group doesn't exist"

echo ""
echo "=========================================="
echo "7. CHECK IAM NODE ROLE"
echo "=========================================="
NODE_ROLE="${CLUSTER_NAME}-node-role"
aws iam get-role --role-name "$NODE_ROLE" \
  --query 'Role.{Name: RoleName, ARN: Arn}' \
  --output json 2>/dev/null || echo "Role not found: $NODE_ROLE"

echo "Attached policies:"
aws iam list-attached-role-policies --role-name "$NODE_ROLE" \
  --query 'AttachedPolicies[*].PolicyName' \
  --output text 2>/dev/null || echo "Could not list policies"

echo ""
echo "=========================================="
echo "DONE - Review output above for issues"
echo "=========================================="
