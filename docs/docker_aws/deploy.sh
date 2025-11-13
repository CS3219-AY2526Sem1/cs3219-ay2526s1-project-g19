#!/bin/bash
set -e

# =========================================
# PeerPrep Complete AWS ECS Deployment Script
# =========================================

echo "========================================="
echo "PeerPrep AWS ECS Deployment"
echo "========================================="

# =========================================
# SECTION 1: INITIAL SETUP & CONFIGURATION
# =========================================

echo ""
echo "Step 1: Setting up AWS configuration..."

# Set AWS configuration
export AWS_REGION=ap-southeast-1
export PROJECT_NAME=peerprep

# Get AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo "Project Name: $PROJECT_NAME"

# =========================================
# SECTION 2: VPC AND NETWORKING SETUP
# =========================================

echo ""
echo "========================================="
echo "Step 2: VPC and Networking Setup"
echo "========================================="

# --- VPC ---
echo "Creating/Finding VPC..."
export VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION \
  --filters "Name=tag:Name,Values=${PROJECT_NAME}-vpc" \
  --query "Vpcs[0].VpcId" --output text)

if [ "$VPC_ID" = "None" ]; then
  echo "Creating new VPC..."
  VPC_ID=$(aws ec2 create-vpc --region $AWS_REGION \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${PROJECT_NAME}-vpc}]" \
    --query "Vpc.VpcId" --output text)
  echo "✓ VPC created: $VPC_ID"
else
  echo "✓ VPC found: $VPC_ID"
fi

# Enable DNS support and hostnames
aws ec2 modify-vpc-attribute --region $AWS_REGION --vpc-id $VPC_ID --enable-dns-support "{\"Value\":true}"
aws ec2 modify-vpc-attribute --region $AWS_REGION --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}"

# --- Subnets ---
echo ""
echo "Creating subnets..."

declare -A SUBNETS=(
  ["public-1a"]="10.0.1.0/24"
  ["public-1b"]="10.0.2.0/24"
  ["private-1a"]="10.0.10.0/24"
  ["private-1b"]="10.0.20.0/24"
)

for NAME in "${!SUBNETS[@]}"; do
  CIDR=${SUBNETS[$NAME]}
  AZ="${AWS_REGION}${NAME: -1}"
  SUBNET_ID=$(aws ec2 describe-subnets --region $AWS_REGION \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-${NAME}" \
    --query "Subnets[0].SubnetId" --output text)
  if [ "$SUBNET_ID" = "None" ]; then
    echo "Creating subnet ${NAME}..."
    aws ec2 create-subnet --region $AWS_REGION --vpc-id $VPC_ID \
      --cidr-block $CIDR --availability-zone $AZ \
      --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-${NAME}}]" \
      >/dev/null
    echo "✓ Subnet ${NAME} created"
  else
    echo "✓ Subnet ${NAME} exists"
  fi
done

# Export subnet IDs
export PRIVATE_SUBNET_1A=$(aws ec2 describe-subnets --region $AWS_REGION --filters "Name=tag:Name,Values=${PROJECT_NAME}-private-1a" "Name=vpc-id,Values=$VPC_ID" --query "Subnets[0].SubnetId" --output text)
export PRIVATE_SUBNET_1B=$(aws ec2 describe-subnets --region $AWS_REGION --filters "Name=tag:Name,Values=${PROJECT_NAME}-private-1b" "Name=vpc-id,Values=$VPC_ID" --query "Subnets[0].SubnetId" --output text)
export PUBLIC_SUBNET_1A=$(aws ec2 describe-subnets --region $AWS_REGION --filters "Name=tag:Name,Values=${PROJECT_NAME}-public-1a" "Name=vpc-id,Values=$VPC_ID" --query "Subnets[0].SubnetId" --output text)
export PUBLIC_SUBNET_1B=$(aws ec2 describe-subnets --region $AWS_REGION --filters "Name=tag:Name,Values=${PROJECT_NAME}-public-1b" "Name=vpc-id,Values=$VPC_ID" --query "Subnets[0].SubnetId" --output text)

echo ""
echo "--- Subnet Verification ---"
echo "PRIVATE_SUBNET_1A: $PRIVATE_SUBNET_1A"
echo "PRIVATE_SUBNET_1B: $PRIVATE_SUBNET_1B"
echo "PUBLIC_SUBNET_1A: $PUBLIC_SUBNET_1A"
echo "PUBLIC_SUBNET_1B: $PUBLIC_SUBNET_1B"

# --- Internet Gateway ---
echo ""
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 describe-internet-gateways --region $AWS_REGION \
  --filters "Name=tag:Name,Values=${PROJECT_NAME}-igw" \
  --query "InternetGateways[0].InternetGatewayId" --output text)

if [ "$IGW_ID" = "None" ]; then
  IGW_ID=$(aws ec2 create-internet-gateway --region $AWS_REGION \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${PROJECT_NAME}-igw}]" \
    --query "InternetGateway.InternetGatewayId" --output text)
  aws ec2 attach-internet-gateway --region $AWS_REGION \
    --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
  echo "✓ Internet Gateway created: $IGW_ID"
else
  echo "✓ Internet Gateway exists: $IGW_ID"
fi

# --- NAT Gateway ---
echo ""
echo "Creating NAT Gateway..."
NAT_GW_ID=$(aws ec2 describe-nat-gateways --region $AWS_REGION \
  --filter "Name=tag:Name,Values=${PROJECT_NAME}-nat" "Name=state,Values=available" \
  --query "NatGateways[0].NatGatewayId" --output text 2>/dev/null)

if [ "$NAT_GW_ID" = "None" ] || [ -z "$NAT_GW_ID" ]; then
  echo "Allocating Elastic IP..."
  EIP_ALLOC_ID=$(aws ec2 allocate-address --region $AWS_REGION \
    --domain vpc --query "AllocationId" --output text)

  echo "Creating NAT Gateway..."
  NAT_GW_ID=$(aws ec2 create-nat-gateway --region $AWS_REGION \
    --subnet-id $PUBLIC_SUBNET_1A \
    --allocation-id $EIP_ALLOC_ID \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=${PROJECT_NAME}-nat}]" \
    --query "NatGateway.NatGatewayId" --output text)

  echo "Waiting for NAT Gateway to be available..."
  aws ec2 wait nat-gateway-available --region $AWS_REGION --nat-gateway-ids $NAT_GW_ID
  echo "✓ NAT Gateway created: $NAT_GW_ID"
else
  echo "✓ NAT Gateway exists: $NAT_GW_ID"
fi

# --- Route Tables ---
echo ""
echo "Configuring route tables..."

# Public route table (for IGW)
PUBLIC_RT_ID=$(aws ec2 describe-route-tables --region $AWS_REGION \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PROJECT_NAME}-public-rt" \
  --query "RouteTables[0].RouteTableId" --output text)

if [ "$PUBLIC_RT_ID" = "None" ] || [ -z "$PUBLIC_RT_ID" ]; then
  echo "Creating public route table..."
  PUBLIC_RT_ID=$(aws ec2 create-route-table --region $AWS_REGION \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-rt}]" \
    --query "RouteTable.RouteTableId" --output text)

  # Add route to IGW
  aws ec2 create-route --region $AWS_REGION \
    --route-table-id $PUBLIC_RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID

  echo "✓ Public route table created: $PUBLIC_RT_ID"
else
  echo "✓ Public route table exists: $PUBLIC_RT_ID"
fi

# Associate public subnets with public route table
aws ec2 associate-route-table --region $AWS_REGION \
  --route-table-id $PUBLIC_RT_ID \
  --subnet-id $PUBLIC_SUBNET_1A 2>/dev/null || echo "  Public subnet 1A already associated"

aws ec2 associate-route-table --region $AWS_REGION \
  --route-table-id $PUBLIC_RT_ID \
  --subnet-id $PUBLIC_SUBNET_1B 2>/dev/null || echo "  Public subnet 1B already associated"

# Private route table (for NAT)
PRIVATE_RT_ID=$(aws ec2 describe-route-tables --region $AWS_REGION \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PROJECT_NAME}-private-rt" \
  --query "RouteTables[0].RouteTableId" --output text)

if [ "$PRIVATE_RT_ID" = "None" ] || [ -z "$PRIVATE_RT_ID" ]; then
  echo "Creating private route table..."
  PRIVATE_RT_ID=$(aws ec2 create-route-table --region $AWS_REGION \
    --vpc-id $VPC_ID \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-rt}]" \
    --query "RouteTable.RouteTableId" --output text)

  # Add route to NAT Gateway
  aws ec2 create-route --region $AWS_REGION \
    --route-table-id $PRIVATE_RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_ID

  echo "✓ Private route table created: $PRIVATE_RT_ID"
else
  # Update existing route table to use NAT Gateway
  aws ec2 create-route --region $AWS_REGION \
    --route-table-id $PRIVATE_RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_ID 2>/dev/null || \
  aws ec2 replace-route --region $AWS_REGION \
    --route-table-id $PRIVATE_RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_ID

  echo "✓ Private route table exists: $PRIVATE_RT_ID"
fi

# Associate private subnets with private route table
aws ec2 associate-route-table --region $AWS_REGION \
  --route-table-id $PRIVATE_RT_ID \
  --subnet-id $PRIVATE_SUBNET_1A 2>/dev/null || echo "  Private subnet 1A already associated"

aws ec2 associate-route-table --region $AWS_REGION \
  --route-table-id $PRIVATE_RT_ID \
  --subnet-id $PRIVATE_SUBNET_1B 2>/dev/null || echo "  Private subnet 1B already associated"

echo "✓ Route tables configured"

echo ""
echo "✅ VPC and networking setup complete!"

# =========================================
# SECTION 3: SECURITY GROUPS
# =========================================

echo ""
echo "========================================="
echo "Step 3: Creating Security Groups"
echo "========================================="

# ALB Security Group
echo "Creating ALB Security Group..."
ALB_SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION \
  --filters "Name=group-name,Values=peerprep-alb-sg" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [ "$ALB_SG_ID" = "None" ] || [ -z "$ALB_SG_ID" ]; then
  aws ec2 create-security-group \
    --group-name peerprep-alb-sg \
    --description "Security group for PeerPrep ALB" \
    --vpc-id $VPC_ID \
    --region $AWS_REGION

  export ALB_SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION \
    --filters "Name=group-name,Values=peerprep-alb-sg" \
    --query "SecurityGroups[0].GroupId" \
    --output text)

  # Allow HTTP
  aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION

  # Allow HTTPS
  aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION

  echo "✓ ALB Security Group created: $ALB_SG_ID"
else
  export ALB_SG_ID
  echo "✓ ALB Security Group exists: $ALB_SG_ID"
fi

# ECS Tasks Security Group
echo ""
echo "Creating ECS Tasks Security Group..."
ECS_TASKS_SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION \
  --filters "Name=group-name,Values=peerprep-ecs-tasks-sg" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [ "$ECS_TASKS_SG_ID" = "None" ] || [ -z "$ECS_TASKS_SG_ID" ]; then
  aws ec2 create-security-group \
    --group-name peerprep-ecs-tasks-sg \
    --description "Security group for PeerPrep ECS tasks" \
    --vpc-id $VPC_ID \
    --region $AWS_REGION

  export ECS_TASKS_SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION \
    --filters "Name=group-name,Values=peerprep-ecs-tasks-sg" \
    --query "SecurityGroups[0].GroupId" \
    --output text)

  # Allow port 8000 from ALB
  aws ec2 authorize-security-group-ingress \
    --group-id $ECS_TASKS_SG_ID \
    --protocol tcp \
    --port 8000 \
    --source-group $ALB_SG_ID \
    --region $AWS_REGION

  # Allow port 80 from ALB (for frontend nginx)
  aws ec2 authorize-security-group-ingress \
    --group-id $ECS_TASKS_SG_ID \
    --protocol tcp \
    --port 80 \
    --source-group $ALB_SG_ID \
    --region $AWS_REGION

  # Allow all traffic from other ECS tasks (service-to-service)
  aws ec2 authorize-security-group-ingress \
    --group-id $ECS_TASKS_SG_ID \
    --protocol -1 \
    --source-group $ECS_TASKS_SG_ID \
    --region $AWS_REGION

  echo "✓ ECS Tasks Security Group created: $ECS_TASKS_SG_ID"
else
  export ECS_TASKS_SG_ID
  echo "✓ ECS Tasks Security Group exists: $ECS_TASKS_SG_ID"
fi

# RDS Security Group
echo ""
echo "Creating RDS Security Group..."
RDS_SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION \
  --filters "Name=group-name,Values=peerprep-rds-sg" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [ "$RDS_SG_ID" = "None" ] || [ -z "$RDS_SG_ID" ]; then
  aws ec2 create-security-group \
    --group-name peerprep-rds-sg \
    --description "Security group for PeerPrep RDS" \
    --vpc-id $VPC_ID \
    --region $AWS_REGION

  export RDS_SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION \
    --filters "Name=group-name,Values=peerprep-rds-sg" \
    --query "SecurityGroups[0].GroupId" \
    --output text)

  # Allow PostgreSQL from ECS tasks
  aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG_ID \
    --protocol tcp \
    --port 5432 \
    --source-group $ECS_TASKS_SG_ID \
    --region $AWS_REGION

  echo "✓ RDS Security Group created: $RDS_SG_ID"
else
  export RDS_SG_ID
  echo "✓ RDS Security Group exists: $RDS_SG_ID"
fi

# Redis Security Group
echo ""
echo "Creating Redis Security Group..."
REDIS_SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION \
  --filters "Name=group-name,Values=peerprep-redis-sg" \
  --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [ "$REDIS_SG_ID" = "None" ] || [ -z "$REDIS_SG_ID" ]; then
  aws ec2 create-security-group \
    --group-name peerprep-redis-sg \
    --description "Security group for PeerPrep Redis" \
    --vpc-id $VPC_ID \
    --region $AWS_REGION

  export REDIS_SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION \
    --filters "Name=group-name,Values=peerprep-redis-sg" \
    --query "SecurityGroups[0].GroupId" \
    --output text)

  # Allow Redis from ECS tasks
  aws ec2 authorize-security-group-ingress \
    --group-id $REDIS_SG_ID \
    --protocol tcp \
    --port 6379 \
    --source-group $ECS_TASKS_SG_ID \
    --region $AWS_REGION

  echo "✓ Redis Security Group created: $REDIS_SG_ID"
else
  export REDIS_SG_ID
  echo "✓ Redis Security Group exists: $REDIS_SG_ID"
fi

echo ""
echo "--- Security Group Verification ---"
echo "ALB_SG_ID: $ALB_SG_ID"
echo "ECS_TASKS_SG_ID: $ECS_TASKS_SG_ID"
echo "RDS_SG_ID: $RDS_SG_ID"
echo "REDIS_SG_ID: $REDIS_SG_ID"

echo ""
echo "✅ Security groups created!"

# =========================================
# SECTION 4: RDS POSTGRESQL
# =========================================

echo ""
echo "========================================="
echo "Step 4: Creating RDS PostgreSQL"
echo "========================================="

# Create DB subnet group
echo "Creating DB subnet group..."
DB_SUBNET_GROUP_EXISTS=$(aws rds describe-db-subnet-groups --region $AWS_REGION \
  --db-subnet-group-name peerprep-db-subnet-group \
  --query "DBSubnetGroups[0].DBSubnetGroupName" --output text 2>/dev/null)

if [ "$DB_SUBNET_GROUP_EXISTS" = "None" ] || [ -z "$DB_SUBNET_GROUP_EXISTS" ]; then
  aws rds create-db-subnet-group \
    --db-subnet-group-name peerprep-db-subnet-group \
    --db-subnet-group-description "Subnet group for PeerPrep RDS" \
    --subnet-ids $PRIVATE_SUBNET_1A $PRIVATE_SUBNET_1B \
    --region $AWS_REGION
  echo "✓ DB subnet group created"
else
  echo "✓ DB subnet group exists"
fi

# Create RDS PostgreSQL instance
echo ""
echo "Creating RDS PostgreSQL instance..."
RDS_EXISTS=$(aws rds describe-db-instances --region $AWS_REGION \
  --db-instance-identifier peerprep-db \
  --query "DBInstances[0].DBInstanceIdentifier" --output text 2>/dev/null)

if [ "$RDS_EXISTS" = "None" ] || [ -z "$RDS_EXISTS" ]; then
  aws rds create-db-instance \
    --db-instance-identifier peerprep-db \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version 15.14 \
    --master-username peerprep_admin \
    --master-user-password 'YourSecurePassword123!' \
    --allocated-storage 20 \
    --storage-type gp3 \
    --vpc-security-group-ids $RDS_SG_ID \
    --db-subnet-group-name peerprep-db-subnet-group \
    --multi-az \
    --publicly-accessible false \
    --backup-retention-period 7 \
    --preferred-backup-window "03:00-04:00" \
    --preferred-maintenance-window "mon:04:00-mon:05:00" \
    --enable-cloudwatch-logs-exports '["postgresql"]' \
    --tags Key=Name,Value=peerprep-db \
    --region $AWS_REGION

  echo "Waiting for RDS instance to be available (this takes ~10 minutes)..."
  aws rds wait db-instance-available --db-instance-identifier peerprep-db --region $AWS_REGION
  echo "✓ RDS PostgreSQL instance created"
else
  echo "✓ RDS PostgreSQL instance exists"
fi

# Get RDS endpoint
export RDS_ENDPOINT=$(aws rds describe-db-instances --region $AWS_REGION \
  --db-instance-identifier peerprep-db \
  --query "DBInstances[0].Endpoint.Address" \
  --output text)

echo "RDS Endpoint: $RDS_ENDPOINT"

# Create individual databases automatically (skip prompt)
echo ""
echo "Creating databases..."
if command -v psql &> /dev/null && [ "$RDS_ENDPOINT" != "None" ] && [ ! -z "$RDS_ENDPOINT" ]; then
  PGPASSWORD='YourSecurePassword123!' psql \
    -h $RDS_ENDPOINT \
    -U peerprep_admin \
    -d postgres \
    -c "CREATE DATABASE user_db;" 2>/dev/null || echo "  user_db may already exist"

  PGPASSWORD='YourSecurePassword123!' psql \
    -h $RDS_ENDPOINT \
    -U peerprep_admin \
    -d postgres \
    -c "CREATE DATABASE question_db;" 2>/dev/null || echo "  question_db may already exist"

  PGPASSWORD='YourSecurePassword123!' psql \
    -h $RDS_ENDPOINT \
    -U peerprep_admin \
    -d postgres \
    -c "CREATE DATABASE matching_db;" 2>/dev/null || echo "  matching_db may already exist"

  PGPASSWORD='YourSecurePassword123!' psql \
    -h $RDS_ENDPOINT \
    -U peerprep_admin \
    -d postgres \
    -c "CREATE DATABASE history_db;" 2>/dev/null || echo "  history_db may already exist"

  echo "✓ Databases created!"
else
  echo "⚠ Skipping database creation (psql not available or RDS not ready)"
  echo "  Install psql with: brew install postgresql@15"
  echo "  Then manually run the database creation commands"
fi

echo ""
echo "✅ RDS PostgreSQL setup complete!"

# =========================================
# SECTION 5: ELASTICACHE REDIS
# =========================================

echo ""
echo "========================================="
echo "Step 5: Creating ElastiCache Redis"
echo "========================================="

# Create Redis subnet group
echo "Creating Redis subnet group..."
REDIS_SUBNET_GROUP_EXISTS=$(aws elasticache describe-cache-subnet-groups --region $AWS_REGION \
  --cache-subnet-group-name peerprep-redis-subnet-group \
  --query "CacheSubnetGroups[0].CacheSubnetGroupName" --output text 2>/dev/null)

if [ "$REDIS_SUBNET_GROUP_EXISTS" = "None" ] || [ -z "$REDIS_SUBNET_GROUP_EXISTS" ]; then
  aws elasticache create-cache-subnet-group \
    --cache-subnet-group-name peerprep-redis-subnet-group \
    --cache-subnet-group-description "Subnet group for PeerPrep Redis" \
    --subnet-ids $PRIVATE_SUBNET_1A $PRIVATE_SUBNET_1B \
    --region $AWS_REGION
  echo "✓ Redis subnet group created"
else
  echo "✓ Redis subnet group exists"
fi

# Create Redis cluster
echo ""
echo "Creating Redis replication group..."
REDIS_EXISTS=$(aws elasticache describe-replication-groups --region $AWS_REGION \
  --replication-group-id peerprep-redis \
  --query "ReplicationGroups[0].ReplicationGroupId" --output text 2>/dev/null)

if [ "$REDIS_EXISTS" = "None" ] || [ -z "$REDIS_EXISTS" ]; then
  aws elasticache create-replication-group \
    --replication-group-id peerprep-redis \
    --replication-group-description "PeerPrep Redis cluster" \
    --engine redis \
    --cache-node-type cache.t3.micro \
    --num-cache-clusters 2 \
    --automatic-failover-enabled \
    --cache-subnet-group-name peerprep-redis-subnet-group \
    --security-group-ids $REDIS_SG_ID \
    --preferred-maintenance-window "sun:05:00-sun:06:00" \
    --snapshot-retention-limit 5 \
    --snapshot-window "03:00-04:00" \
    --region $AWS_REGION

  echo "Waiting for Redis cluster to be available (this takes ~5 minutes)..."
  aws elasticache wait replication-group-available --replication-group-id peerprep-redis --region $AWS_REGION
  echo "✓ Redis cluster created"
else
  echo "✓ Redis cluster exists"
fi

# Get Redis endpoint
export REDIS_ENDPOINT=$(aws elasticache describe-replication-groups --region $AWS_REGION \
  --replication-group-id peerprep-redis \
  --query "ReplicationGroups[0].NodeGroups[0].PrimaryEndpoint.Address" \
  --output text)

echo "Redis Endpoint: $REDIS_ENDPOINT"

echo ""
echo "✅ ElastiCache Redis setup complete!"

# =========================================
# SECTION 6: ECS CLUSTER
# =========================================

echo ""
echo "========================================="
echo "Step 6: Creating ECS Cluster"
echo "========================================="

# First, create the ECS service-linked role if it doesn't exist
echo "Checking for ECS service-linked role..."
aws iam get-role --role-name AWSServiceRoleForECS 2>/dev/null || \
  aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com && \
  echo "✓ ECS service-linked role created"

# Wait a moment for the role to propagate
sleep 5

# Check if cluster exists
ECS_CLUSTER_EXISTS=$(aws ecs describe-clusters --region $AWS_REGION \
  --clusters peerprep-cluster \
  --query "clusters[0].clusterName" --output text 2>/dev/null)

if [ "$ECS_CLUSTER_EXISTS" = "None" ] || [ -z "$ECS_CLUSTER_EXISTS" ]; then
  # Create cluster without capacity providers initially
  aws ecs create-cluster \
    --cluster-name peerprep-cluster \
    --region $AWS_REGION
  
  echo "✓ ECS Cluster created"
  
  # Add capacity providers after cluster creation
  echo "Adding capacity providers to cluster..."
  aws ecs put-cluster-capacity-providers \
    --cluster peerprep-cluster \
    --capacity-providers FARGATE FARGATE_SPOT \
    --default-capacity-provider-strategy \
      capacityProvider=FARGATE,weight=1 \
      capacityProvider=FARGATE_SPOT,weight=4 \
    --region $AWS_REGION
  
  echo "✓ Capacity providers configured"
else
  echo "✓ ECS Cluster exists"
fi

echo ""
echo "✅ ECS Cluster setup complete!"
# =========================================
# SECTION 7: CLOUD MAP (SERVICE DISCOVERY)
# =========================================

echo ""
echo "========================================="
echo "Step 7: Creating Cloud Map Namespace"
echo "========================================="

# Check if namespace already exists
NAMESPACE_EXISTS=$(aws servicediscovery list-namespaces --region $AWS_REGION \
  --filters Name=TYPE,Values=DNS_PRIVATE,Condition=EQ \
  --query "Namespaces[?Name=='peerprep.internal'].Id" --output text 2>/dev/null)

if [ -z "$NAMESPACE_EXISTS" ]; then
  echo "Creating private DNS namespace..."
  OPERATION_ID=$(aws servicediscovery create-private-dns-namespace \
    --name peerprep.internal \
    --vpc $VPC_ID \
    --description "Private DNS namespace for PeerPrep services" \
    --region $AWS_REGION \
    --query "OperationId" --output text)
  
  echo "Operation ID: $OPERATION_ID"
  echo "Waiting for namespace to be created (this may take up to 60 seconds)..."
  
  # Wait for the operation to complete
  COUNTER=0
  MAX_ATTEMPTS=12
  
  while [ $COUNTER -lt $MAX_ATTEMPTS ]; do
    sleep 5
    COUNTER=$((COUNTER+1))
    
    # Check operation status
    STATUS=$(aws servicediscovery get-operation \
      --operation-id $OPERATION_ID \
      --region $AWS_REGION \
      --query "Operation.Status" --output text 2>/dev/null)
    
    if [ "$STATUS" = "SUCCESS" ]; then
      echo "✓ Namespace created successfully"
      break
    elif [ "$STATUS" = "FAIL" ]; then
      echo "❌ Namespace creation failed"
      aws servicediscovery get-operation --operation-id $OPERATION_ID --region $AWS_REGION
      exit 1
    else
      echo "  Still creating... (attempt $COUNTER/$MAX_ATTEMPTS)"
    fi
  done
  
  # Extra wait to ensure it's fully propagated
  sleep 5
else
  echo "✓ Namespace already exists"
fi

# Get the namespace ID
export NAMESPACE_ID=$(aws servicediscovery list-namespaces --region $AWS_REGION \
  --filters Name=TYPE,Values=DNS_PRIVATE,Condition=EQ \
  --query "Namespaces[?Name=='peerprep.internal'].Id" \
  --output text)

if [ -z "$NAMESPACE_ID" ]; then
  echo "❌ Error: Could not retrieve namespace ID"
  echo "Listing all namespaces:"
  aws servicediscovery list-namespaces --region $AWS_REGION
  exit 1
fi

echo "Namespace ID: $NAMESPACE_ID"

echo ""
echo "✅ Cloud Map namespace setup complete!"

# =========================================
# SECTION 8: APPLICATION LOAD BALANCER
# =========================================

echo ""
echo "========================================="
echo "Step 8: Creating Application Load Balancer"
echo "========================================="

# Create ALB
echo "Creating ALB..."
ALB_EXISTS=$(aws elbv2 describe-load-balancers --region $AWS_REGION \
  --names peerprep-alb \
  --query "LoadBalancers[0].LoadBalancerName" --output text 2>/dev/null)

if [ "$ALB_EXISTS" = "None" ] || [ -z "$ALB_EXISTS" ]; then
  aws elbv2 create-load-balancer \
    --name peerprep-alb \
    --subnets $PUBLIC_SUBNET_1A $PUBLIC_SUBNET_1B \
    --security-groups $ALB_SG_ID \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --region $AWS_REGION

  echo "✓ ALB created"
else
  echo "✓ ALB exists"
fi

export ALB_ARN=$(aws elbv2 describe-load-balancers --region $AWS_REGION \
  --names peerprep-alb \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text)

export ALB_DNS=$(aws elbv2 describe-load-balancers --region $AWS_REGION \
  --names peerprep-alb \
  --query "LoadBalancers[0].DNSName" \
  --output text)

echo "ALB DNS: $ALB_DNS"

# Create target groups
echo ""
echo "Creating target groups..."

# Frontend target group
TG_EXISTS=$(aws elbv2 describe-target-groups --region $AWS_REGION \
  --names peerprep-frontend-tg \
  --query "TargetGroups[0].TargetGroupName" --output text 2>/dev/null)

if [ "$TG_EXISTS" = "None" ] || [ -z "$TG_EXISTS" ]; then
  aws elbv2 create-target-group \
    --name peerprep-frontend-tg \
    --protocol HTTP \
    --port 80 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-path /health \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 3 \
    --region $AWS_REGION
  echo "✓ Frontend target group created"
else
  echo "✓ Frontend target group exists"
fi

export FRONTEND_TG_ARN=$(aws elbv2 describe-target-groups --region $AWS_REGION \
  --names peerprep-frontend-tg \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text)

# User service target group
TG_EXISTS=$(aws elbv2 describe-target-groups --region $AWS_REGION \
  --names peerprep-user-tg \
  --query "TargetGroups[0].TargetGroupName" --output text 2>/dev/null)

if [ "$TG_EXISTS" = "None" ] || [ -z "$TG_EXISTS" ]; then
  aws elbv2 create-target-group \
    --name peerprep-user-tg \
    --protocol HTTP \
    --port 8000 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-path /health \
    --health-check-interval-seconds 30 \
    --region $AWS_REGION
  echo "✓ User service target group created"
else
  echo "✓ User service target group exists"
fi

export USER_TG_ARN=$(aws elbv2 describe-target-groups --region $AWS_REGION \
  --names peerprep-user-tg \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text)

# Question service target group
TG_EXISTS=$(aws elbv2 describe-target-groups --region $AWS_REGION \
  --names peerprep-question-tg \
  --query "TargetGroups[0].TargetGroupName" --output text 2>/dev/null)

if [ "$TG_EXISTS" = "None" ] || [ -z "$TG_EXISTS" ]; then
  aws elbv2 create-target-group \
    --name peerprep-question-tg \
    --protocol HTTP \
    --port 8000 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-path /health \
    --region $AWS_REGION
  echo "✓ Question service target group created"
else
  echo "✓ Question service target group exists"
fi

export QUESTION_TG_ARN=$(aws elbv2 describe-target-groups --region $AWS_REGION \
  --names peerprep-question-tg \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text)

# Matching service target group
TG_EXISTS=$(aws elbv2 describe-target-groups --region $AWS_REGION \
  --names peerprep-matching-tg \
  --query "TargetGroups[0].TargetGroupName" --output text 2>/dev/null)

if [ "$TG_EXISTS" = "None" ] || [ -z "$TG_EXISTS" ]; then
  aws elbv2 create-target-group \
    --name peerprep-matching-tg \
    --protocol HTTP \
    --port 8000 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-path /health \
    --region $AWS_REGION
  echo "✓ Matching service target group created"
else
  echo "✓ Matching service target group exists"
fi

export MATCHING_TG_ARN=$(aws elbv2 describe-target-groups --region $AWS_REGION \
  --names peerprep-matching-tg \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text)

# History service target group
TG_EXISTS=$(aws elbv2 describe-target-groups --region $AWS_REGION \
  --names peerprep-history-tg \
  --query "TargetGroups[0].TargetGroupName" --output text 2>/dev/null)

if [ "$TG_EXISTS" = "None" ] || [ -z "$TG_EXISTS" ]; then
  aws elbv2 create-target-group \
    --name peerprep-history-tg \
    --protocol HTTP \
    --port 8000 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-path /health \
    --region $AWS_REGION
  echo "✓ History service target group created"
else
  echo "✓ History service target group exists"
fi

export HISTORY_TG_ARN=$(aws elbv2 describe-target-groups --region $AWS_REGION \
  --names peerprep-history-tg \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text)

# Collaboration service target group
TG_EXISTS=$(aws elbv2 describe-target-groups --region $AWS_REGION \
  --names peerprep-collab-tg \
  --query "TargetGroups[0].TargetGroupName" --output text 2>/dev/null)

if [ "$TG_EXISTS" = "None" ] || [ -z "$TG_EXISTS" ]; then
  aws elbv2 create-target-group \
    --name peerprep-collab-tg \
    --protocol HTTP \
    --port 8000 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-path /health \
    --region $AWS_REGION
  echo "✓ Collaboration service target group created"
else
  echo "✓ Collaboration service target group exists"
fi

export COLLAB_TG_ARN=$(aws elbv2 describe-target-groups --region $AWS_REGION \
  --names peerprep-collab-tg \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text)

# Chat service target group
TG_EXISTS=$(aws elbv2 describe-target-groups --region $AWS_REGION \
  --names peerprep-chat-tg \
  --query "TargetGroups[0].TargetGroupName" --output text 2>/dev/null)

if [ "$TG_EXISTS" = "None" ] || [ -z "$TG_EXISTS" ]; then
  aws elbv2 create-target-group \
    --name peerprep-chat-tg \
    --protocol HTTP \
    --port 8000 \
    --vpc-id $VPC_ID \
    --target-type ip \
    --health-check-enabled \
    --health-check-path /health \
    --region $AWS_REGION
  echo "✓ Chat service target group created"
else
  echo "✓ Chat service target group exists"
fi

export CHAT_TG_ARN=$(aws elbv2 describe-target-groups --region $AWS_REGION \
  --names peerprep-chat-tg \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text)

# Create HTTP listener (port 80)
echo ""
echo "Creating HTTP listener..."
LISTENER_EXISTS=$(aws elbv2 describe-listeners --region $AWS_REGION \
  --load-balancer-arn $ALB_ARN \
  --query "Listeners[?Port==\`80\`].ListenerArn" --output text 2>/dev/null)

if [ -z "$LISTENER_EXISTS" ]; then
  aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$FRONTEND_TG_ARN \
    --region $AWS_REGION
  echo "✓ HTTP listener created"
else
  echo "✓ HTTP listener exists"
fi

export HTTP_LISTENER_ARN=$(aws elbv2 describe-listeners --region $AWS_REGION \
  --load-balancer-arn $ALB_ARN \
  --query "Listeners[?Port==\`80\`].ListenerArn" \
  --output text)

# Create listener rules for path-based routing
echo ""
echo "Creating listener rules..."

# User service: /user-service-api/*
RULE_EXISTS=$(aws elbv2 describe-rules --region $AWS_REGION \
  --listener-arn $HTTP_LISTENER_ARN \
  --query "Rules[?Priority==\`10\`].RuleArn" --output text 2>/dev/null)

if [ -z "$RULE_EXISTS" ]; then
  aws elbv2 create-rule \
    --listener-arn $HTTP_LISTENER_ARN \
    --priority 10 \
    --conditions Field=path-pattern,Values='/user-service-api/*' \
    --actions Type=forward,TargetGroupArn=$USER_TG_ARN \
    --region $AWS_REGION
  echo "✓ User service rule created"
else
  echo "✓ User service rule exists"
fi

# Question service: /question-service-api/*
RULE_EXISTS=$(aws elbv2 describe-rules --region $AWS_REGION \
  --listener-arn $HTTP_LISTENER_ARN \
  --query "Rules[?Priority==\`20\`].RuleArn" --output text 2>/dev/null)

if [ -z "$RULE_EXISTS" ]; then
  aws elbv2 create-rule \
    --listener-arn $HTTP_LISTENER_ARN \
    --priority 20 \
    --conditions Field=path-pattern,Values='/question-service-api/*' \
    --actions Type=forward,TargetGroupArn=$QUESTION_TG_ARN \
    --region $AWS_REGION
  echo "✓ Question service rule created"
else
  echo "✓ Question service rule exists"
fi

# Matching service: /matching-service-api/*
RULE_EXISTS=$(aws elbv2 describe-rules --region $AWS_REGION \
  --listener-arn $HTTP_LISTENER_ARN \
  --query "Rules[?Priority==\`30\`].RuleArn" --output text 2>/dev/null)

if [ -z "$RULE_EXISTS" ]; then
  aws elbv2 create-rule \
    --listener-arn $HTTP_LISTENER_ARN \
    --priority 30 \
    --conditions Field=path-pattern,Values='/matching-service-api/*' \
    --actions Type=forward,TargetGroupArn=$MATCHING_TG_ARN \
    --region $AWS_REGION
  echo "✓ Matching service rule created"
else
  echo "✓ Matching service rule exists"
fi

# History service: /history-service-api/*
RULE_EXISTS=$(aws elbv2 describe-rules --region $AWS_REGION \
  --listener-arn $HTTP_LISTENER_ARN \
  --query "Rules[?Priority==\`40\`].RuleArn" --output text 2>/dev/null)

if [ -z "$RULE_EXISTS" ]; then
  aws elbv2 create-rule \
    --listener-arn $HTTP_LISTENER_ARN \
    --priority 40 \
    --conditions Field=path-pattern,Values='/history-service-api/*' \
    --actions Type=forward,TargetGroupArn=$HISTORY_TG_ARN \
    --region $AWS_REGION
  echo "✓ History service rule created"
else
  echo "✓ History service rule exists"
fi

# Collaboration service: /collaboration-service-api/*
RULE_EXISTS=$(aws elbv2 describe-rules --region $AWS_REGION \
  --listener-arn $HTTP_LISTENER_ARN \
  --query "Rules[?Priority==\`50\`].RuleArn" --output text 2>/dev/null)

if [ -z "$RULE_EXISTS" ]; then
  aws elbv2 create-rule \
    --listener-arn $HTTP_LISTENER_ARN \
    --priority 50 \
    --conditions Field=path-pattern,Values='/collaboration-service-api/*' \
    --actions Type=forward,TargetGroupArn=$COLLAB_TG_ARN \
    --region $AWS_REGION
  echo "✓ Collaboration service rule created"
else
  echo "✓ Collaboration service rule exists"
fi

# Chat service: /chat-service-api/*
RULE_EXISTS=$(aws elbv2 describe-rules --region $AWS_REGION \
  --listener-arn $HTTP_LISTENER_ARN \
  --query "Rules[?Priority==\`60\`].RuleArn" --output text 2>/dev/null)

if [ -z "$RULE_EXISTS" ]; then
  aws elbv2 create-rule \
    --listener-arn $HTTP_LISTENER_ARN \
    --priority 60 \
    --conditions Field=path-pattern,Values='/chat-service-api/*' \
    --actions Type=forward,TargetGroupArn=$CHAT_TG_ARN \
    --region $AWS_REGION
  echo "✓ Chat service rule created"
else
  echo "✓ Chat service rule exists"
fi

echo ""
echo "✅ ALB and target groups created!"

# =========================================
# SECTION 9: ECR REPOSITORIES
# =========================================

echo ""
echo "========================================="
echo "Step 9: Creating ECR Repositories"
echo "========================================="

services=("frontend" "user-service" "question-service" "matching-service" "history-service" "collaboration-service" "chat-service")

for service in "${services[@]}"; do
  REPO_EXISTS=$(aws ecr describe-repositories --region $AWS_REGION \
    --repository-names peerprep/$service \
    --query "repositories[0].repositoryName" --output text 2>/dev/null)

  if [ "$REPO_EXISTS" = "None" ] || [ -z "$REPO_EXISTS" ]; then
    aws ecr create-repository \
      --repository-name peerprep/$service \
      --image-scanning-configuration scanOnPush=true \
      --region $AWS_REGION
    echo "✓ Created ECR repository for $service"
  else
    echo "✓ ECR repository for $service exists"
  fi
done

# Login to ECR (optional - only needed for local Docker builds)
echo ""
echo "Logging in to ECR (optional)..."
if command -v docker &> /dev/null; then
  aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com 2>/dev/null || \
    echo "  ⚠ Docker login failed (Docker may not be running - this is OK if images are already in ECR)"
else
  echo "  ⚠ Docker not installed - skipping login (this is OK if images are already in ECR)"
fi

echo ""
echo "✅ ECR repositories created!"

# =========================================
# SECTION 10: IAM ROLES
# =========================================

echo ""
echo "========================================="
echo "Step 10: Creating IAM Roles"
echo "========================================="

# Create ECS Task Execution Role
echo "Creating ECS Task Execution Role..."
ROLE_EXISTS=$(aws iam get-role --role-name ecsTaskExecutionRole \
  --query "Role.RoleName" --output text 2>/dev/null)

if [ "$ROLE_EXISTS" = "None" ] || [ -z "$ROLE_EXISTS" ]; then
  cat > ecs-task-execution-role-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document file://ecs-task-execution-role-trust-policy.json

  aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

  echo "✓ ECS Task Execution Role created"
  rm ecs-task-execution-role-trust-policy.json
else
  echo "✓ ECS Task Execution Role exists"
fi

export ECS_EXECUTION_ROLE_ARN=$(aws iam get-role \
  --role-name ecsTaskExecutionRole \
  --query "Role.Arn" \
  --output text)

# Create ECS Task Role
echo ""
echo "Creating ECS Task Role..."
ROLE_EXISTS=$(aws iam get-role --role-name ecsTaskRole \
  --query "Role.RoleName" --output text 2>/dev/null)

if [ "$ROLE_EXISTS" = "None" ] || [ -z "$ROLE_EXISTS" ]; then
  cat > ecs-task-role-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  aws iam create-role \
    --role-name ecsTaskRole \
    --assume-role-policy-document file://ecs-task-role-trust-policy.json

  echo "✓ ECS Task Role created"
  rm ecs-task-role-trust-policy.json
else
  echo "✓ ECS Task Role exists"
fi

export ECS_TASK_ROLE_ARN=$(aws iam get-role \
  --role-name ecsTaskRole \
  --query "Role.Arn" \
  --output text)

echo ""
echo "--- IAM Role Verification ---"
echo "ECS_EXECUTION_ROLE_ARN: $ECS_EXECUTION_ROLE_ARN"
echo "ECS_TASK_ROLE_ARN: $ECS_TASK_ROLE_ARN"

echo ""
echo "✅ IAM roles created!"

# =========================================
# SECTION 11: BUILD AND PUSH DOCKER IMAGES
# =========================================

echo ""
echo "========================================="
echo "Step 11: Building and Pushing Docker Images"
echo "========================================="

export ECR_BASE=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/peerprep

echo "Skipping Docker image build (images should already be pushed to ECR)"
echo "If you need to rebuild images, run the build commands manually from each service directory"

# Note: Skipping build to avoid prompts. Images should already be in ECR.
# To rebuild manually:
# cd frontend && docker build ... && docker push ...

if false; then
  # Build and push frontend (disabled)
  echo ""
  echo "Building frontend..."
  if [ -d "frontend" ]; then
    cd frontend
    docker build \
      --build-arg VITE_QUESTION_SERVICE_URL=/question-service-api \
      --build-arg VITE_MATCHING_SERVICE_URL=/matching-service-api \
      --build-arg VITE_HISTORY_SERVICE_URL=/history-service-api \
      --build-arg VITE_USER_SERVICE_URL=/user-service-api \
      --build-arg VITE_COLLABORATION_SERVICE_URL=/collaboration-service-api \
      --build-arg VITE_CHAT_SERVICE_URL=/chat-service-api \
      -t $ECR_BASE/frontend:latest \
      --target production .
    docker push $ECR_BASE/frontend:latest
    echo "✓ Frontend pushed to ECR"
    cd ..
  else
    echo "⚠ Frontend directory not found, skipping..."
  fi

  # Build and push user service
  echo ""
  echo "Building user service..."
  if [ -d "user_service" ]; then
    cd user_service
    docker build -t $ECR_BASE/user-service:latest .
    docker push $ECR_BASE/user-service:latest
    echo "✓ User service pushed to ECR"
    cd ..
  else
    echo "⚠ user_service directory not found, skipping..."
  fi

  # Build and push question service
  echo ""
  echo "Building question service..."
  if [ -d "question_service" ]; then
    cd question_service
    docker build -t $ECR_BASE/question-service:latest .
    docker push $ECR_BASE/question-service:latest
    echo "✓ Question service pushed to ECR"
    cd ..
  else
    echo "⚠ question_service directory not found, skipping..."
  fi

  # Build and push matching service
  echo ""
  echo "Building matching service..."
  if [ -d "matching_service" ]; then
    cd matching_service
    docker build -t $ECR_BASE/matching-service:latest .
    docker push $ECR_BASE/matching-service:latest
    echo "✓ Matching service pushed to ECR"
    cd ..
  else
    echo "⚠ matching_service directory not found, skipping..."
  fi

  # Build and push history service
  echo ""
  echo "Building history service..."
  if [ -d "history_service" ]; then
    cd history_service
    docker build -t $ECR_BASE/history-service:latest .
    docker push $ECR_BASE/history-service:latest
    echo "✓ History service pushed to ECR"
    cd ..
  else
    echo "⚠ history_service directory not found, skipping..."
  fi

  # Build and push collaboration service
  echo ""
  echo "Building collaboration service..."
  if [ -d "collaboration_service" ]; then
    cd collaboration_service
    docker build -t $ECR_BASE/collaboration-service:latest .
    docker push $ECR_BASE/collaboration-service:latest
    echo "✓ Collaboration service pushed to ECR"
    cd ..
  else
    echo "⚠ collaboration_service directory not found, skipping..."
  fi

  # Build and push chat service
  echo ""
  echo "Building chat service..."
  if [ -d "chat_service" ]; then
    cd chat_service
    docker build -t $ECR_BASE/chat-service:latest .
    docker push $ECR_BASE/chat-service:latest
    echo "✓ Chat service pushed to ECR"
    cd ..
  else
    echo "⚠ chat_service directory not found, skipping..."
  fi

  echo ""
  echo "✅ All images built and pushed to ECR!"
else
  echo "Skipping Docker image build and push."
fi

# =========================================
# SECTION 12: CREATE TASK DEFINITIONS
# =========================================

echo ""
echo "========================================="
echo "Step 12: Creating ECS Task Definitions"
echo "========================================="

# User Service Task Definition
echo "Creating user service task definition..."
cat > user-service-task-def.json <<EOF
{
  "family": "user-service-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "$ECS_EXECUTION_ROLE_ARN",
  "taskRoleArn": "$ECS_TASK_ROLE_ARN",
  "containerDefinitions": [
    {
      "name": "user-service",
      "image": "$ECR_BASE/user-service:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "PORT", "value": "8000"},
        {"name": "DEBUG", "value": "false"},
        {"name": "DATABASE_URL", "value": "postgresql://peerprep_admin:YourSecurePassword123!@$RDS_ENDPOINT:5432/user_db"},
        {"name": "QUESTION_SERVICE_URL", "value": "http://question-service.peerprep.internal:8000"},
        {"name": "MATCHING_SERVICE_URL", "value": "http://matching-service.peerprep.internal:8000"},
        {"name": "HISTORY_SERVICE_URL", "value": "http://history-service.peerprep.internal:8000"},
        {"name": "COLLABORATION_SERVICE_URL", "value": "http://collaboration-service.peerprep.internal:8000"},
        {"name": "CHAT_SERVICE_URL", "value": "http://chat-service.peerprep.internal:8000"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/user-service",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

aws ecs register-task-definition --cli-input-json file://user-service-task-def.json --region $AWS_REGION
echo "✓ User service task definition registered"

# Question Service Task Definition
echo ""
echo "Creating question service task definition..."
cat > question-service-task-def.json <<EOF
{
  "family": "question-service-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "$ECS_EXECUTION_ROLE_ARN",
  "taskRoleArn": "$ECS_TASK_ROLE_ARN",
  "containerDefinitions": [
    {
      "name": "question-service",
      "image": "$ECR_BASE/question-service:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "PORT", "value": "8000"},
        {"name": "DEBUG", "value": "false"},
        {"name": "DATABASE_URL", "value": "postgresql://peerprep_admin:YourSecurePassword123!@$RDS_ENDPOINT:5432/question_db"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/question-service",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

aws ecs register-task-definition --cli-input-json file://question-service-task-def.json --region $AWS_REGION
echo "✓ Question service task definition registered"

# Matching Service Task Definition
echo ""
echo "Creating matching service task definition..."
cat > matching-service-task-def.json <<EOF
{
  "family": "matching-service-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "$ECS_EXECUTION_ROLE_ARN",
  "taskRoleArn": "$ECS_TASK_ROLE_ARN",
  "containerDefinitions": [
    {
      "name": "matching-service",
      "image": "$ECR_BASE/matching-service:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "PORT", "value": "8000"},
        {"name": "DEBUG", "value": "false"},
        {"name": "DATABASE_URL", "value": "postgresql://peerprep_admin:YourSecurePassword123!@$RDS_ENDPOINT:5432/matching_db"},
        {"name": "REDIS_URL", "value": "redis://$REDIS_ENDPOINT:6379/0"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/matching-service",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

aws ecs register-task-definition --cli-input-json file://matching-service-task-def.json --region $AWS_REGION
echo "✓ Matching service task definition registered"

# History Service Task Definition
echo ""
echo "Creating history service task definition..."
cat > history-service-task-def.json <<EOF
{
  "family": "history-service-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "$ECS_EXECUTION_ROLE_ARN",
  "taskRoleArn": "$ECS_TASK_ROLE_ARN",
  "containerDefinitions": [
    {
      "name": "history-service",
      "image": "$ECR_BASE/history-service:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "PORT", "value": "8000"},
        {"name": "DEBUG", "value": "false"},
        {"name": "DATABASE_URL", "value": "postgresql://peerprep_admin:YourSecurePassword123!@$RDS_ENDPOINT:5432/history_db"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/history-service",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

aws ecs register-task-definition --cli-input-json file://history-service-task-def.json --region $AWS_REGION
echo "✓ History service task definition registered"

# Collaboration Service Task Definition
echo ""
echo "Creating collaboration service task definition..."
cat > collaboration-service-task-def.json <<EOF
{
  "family": "collaboration-service-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "$ECS_EXECUTION_ROLE_ARN",
  "taskRoleArn": "$ECS_TASK_ROLE_ARN",
  "containerDefinitions": [
    {
      "name": "collaboration-service",
      "image": "$ECR_BASE/collaboration-service:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "PORT", "value": "8000"},
        {"name": "DEBUG", "value": "false"},
        {"name": "REDIS_URL", "value": "redis://$REDIS_ENDPOINT:6379/1"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/collaboration-service",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

aws ecs register-task-definition --cli-input-json file://collaboration-service-task-def.json --region $AWS_REGION
echo "✓ Collaboration service task definition registered"

# Chat Service Task Definition
echo ""
echo "Creating chat service task definition..."
cat > chat-service-task-def.json <<EOF
{
  "family": "chat-service-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "$ECS_EXECUTION_ROLE_ARN",
  "taskRoleArn": "$ECS_TASK_ROLE_ARN",
  "containerDefinitions": [
    {
      "name": "chat-service",
      "image": "$ECR_BASE/chat-service:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "PORT", "value": "8000"},
        {"name": "DEBUG", "value": "false"},
        {"name": "REDIS_URL", "value": "redis://$REDIS_ENDPOINT:6379/2"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/chat-service",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

aws ecs register-task-definition --cli-input-json file://chat-service-task-def.json --region $AWS_REGION
echo "✓ Chat service task definition registered"

# Frontend Task Definition
echo ""
echo "Creating frontend task definition..."
cat > frontend-task-def.json <<EOF
{
  "family": "frontend-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "$ECS_EXECUTION_ROLE_ARN",
  "taskRoleArn": "$ECS_TASK_ROLE_ARN",
  "containerDefinitions": [
    {
      "name": "frontend",
      "image": "$ECR_BASE/frontend:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "NGINX_USER_SERVICE_HOST", "value": "user-service.peerprep.internal"},
        {"name": "NGINX_QUESTION_SERVICE_HOST", "value": "question-service.peerprep.internal"},
        {"name": "NGINX_MATCHING_SERVICE_HOST", "value": "matching-service.peerprep.internal"},
        {"name": "NGINX_HISTORY_SERVICE_HOST", "value": "history-service.peerprep.internal"},
        {"name": "NGINX_COLLABORATION_SERVICE_HOST", "value": "collaboration-service.peerprep.internal"},
        {"name": "NGINX_CHAT_SERVICE_HOST", "value": "chat-service.peerprep.internal"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/frontend",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

aws ecs register-task-definition --cli-input-json file://frontend-task-def.json --region $AWS_REGION
echo "✓ Frontend task definition registered"

# Clean up task definition files
rm -f *-task-def.json

echo ""
echo "✅ All task definitions created!"

# =========================================
# SECTION 13: CREATE SERVICE DISCOVERY SERVICES
# =========================================

echo ""
echo "========================================="
echo "Step 13: Creating Service Discovery Services"
echo "========================================="

# Create service discovery for user service
echo "Creating service discovery for user-service..."
USER_SD_EXISTS=$(aws servicediscovery list-services --region $AWS_REGION \
  --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID,Condition=EQ \
  --query "Services[?Name=='user-service'].Arn" --output text 2>/dev/null)

if [ -z "$USER_SD_EXISTS" ]; then
  aws servicediscovery create-service \
    --name user-service \
    --dns-config "NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=10}]" \
    --health-check-custom-config FailureThreshold=1 \
    --region $AWS_REGION
  echo "✓ User service discovery created"
else
  echo "✓ User service discovery exists"
fi

export USER_SD_ARN=$(aws servicediscovery list-services --region $AWS_REGION \
  --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID,Condition=EQ \
  --query "Services[?Name=='user-service'].Arn" \
  --output text)

# Create service discovery for question service
echo ""
echo "Creating service discovery for question-service..."
QUESTION_SD_EXISTS=$(aws servicediscovery list-services --region $AWS_REGION \
  --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID,Condition=EQ \
  --query "Services[?Name=='question-service'].Arn" --output text 2>/dev/null)

if [ -z "$QUESTION_SD_EXISTS" ]; then
  aws servicediscovery create-service \
    --name question-service \
    --dns-config "NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=10}]" \
    --health-check-custom-config FailureThreshold=1 \
    --region $AWS_REGION
  echo "✓ Question service discovery created"
else
  echo "✓ Question service discovery exists"
fi

export QUESTION_SD_ARN=$(aws servicediscovery list-services --region $AWS_REGION \
  --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID,Condition=EQ \
  --query "Services[?Name=='question-service'].Arn" \
  --output text)

# Create service discovery for matching service
echo ""
echo "Creating service discovery for matching-service..."
MATCHING_SD_EXISTS=$(aws servicediscovery list-services --region $AWS_REGION \
  --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID,Condition=EQ \
  --query "Services[?Name=='matching-service'].Arn" --output text 2>/dev/null)

if [ -z "$MATCHING_SD_EXISTS" ]; then
  aws servicediscovery create-service \
    --name matching-service \
    --dns-config "NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=10}]" \
    --health-check-custom-config FailureThreshold=1 \
    --region $AWS_REGION
  echo "✓ Matching service discovery created"
else
  echo "✓ Matching service discovery exists"
fi

export MATCHING_SD_ARN=$(aws servicediscovery list-services --region $AWS_REGION \
  --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID,Condition=EQ \
  --query "Services[?Name=='matching-service'].Arn" \
  --output text)

# Create service discovery for history service
echo ""
echo "Creating service discovery for history-service..."
HISTORY_SD_EXISTS=$(aws servicediscovery list-services --region $AWS_REGION \
  --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID,Condition=EQ \
  --query "Services[?Name=='history-service'].Arn" --output text 2>/dev/null)

if [ -z "$HISTORY_SD_EXISTS" ]; then
  aws servicediscovery create-service \
    --name history-service \
    --dns-config "NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=10}]" \
    --health-check-custom-config FailureThreshold=1 \
    --region $AWS_REGION
  echo "✓ History service discovery created"
else
  echo "✓ History service discovery exists"
fi

export HISTORY_SD_ARN=$(aws servicediscovery list-services --region $AWS_REGION \
  --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID,Condition=EQ \
  --query "Services[?Name=='history-service'].Arn" \
  --output text)

# Create service discovery for collaboration service
echo ""
echo "Creating service discovery for collaboration-service..."
COLLAB_SD_EXISTS=$(aws servicediscovery list-services --region $AWS_REGION \
  --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID,Condition=EQ \
  --query "Services[?Name=='collaboration-service'].Arn" --output text 2>/dev/null)

if [ -z "$COLLAB_SD_EXISTS" ]; then
  aws servicediscovery create-service \
    --name collaboration-service \
    --dns-config "NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=10}]" \
    --health-check-custom-config FailureThreshold=1 \
    --region $AWS_REGION
  echo "✓ Collaboration service discovery created"
else
  echo "✓ Collaboration service discovery exists"
fi

export COLLAB_SD_ARN=$(aws servicediscovery list-services --region $AWS_REGION \
  --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID,Condition=EQ \
  --query "Services[?Name=='collaboration-service'].Arn" \
  --output text)

# Create service discovery for chat service
echo ""
echo "Creating service discovery for chat-service..."
CHAT_SD_EXISTS=$(aws servicediscovery list-services --region $AWS_REGION \
  --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID,Condition=EQ \
  --query "Services[?Name=='chat-service'].Arn" --output text 2>/dev/null)

if [ -z "$CHAT_SD_EXISTS" ]; then
  aws servicediscovery create-service \
    --name chat-service \
    --dns-config "NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=10}]" \
    --health-check-custom-config FailureThreshold=1 \
    --region $AWS_REGION
  echo "✓ Chat service discovery created"
else
  echo "✓ Chat service discovery exists"
fi

export CHAT_SD_ARN=$(aws servicediscovery list-services --region $AWS_REGION \
  --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID,Condition=EQ \
  --query "Services[?Name=='chat-service'].Arn" \
  --output text)

echo ""
echo "✅ Service discovery services created!"

# =========================================
# SECTION 14: CREATE ECS SERVICES
# =========================================

echo ""
echo "========================================="
echo "Step 14: Creating ECS Services"
echo "========================================="

# Create user service
echo "Creating user ECS service..."
USER_SERVICE_EXISTS=$(aws ecs describe-services --region $AWS_REGION \
  --cluster peerprep-cluster \
  --services user-service \
  --query "services[0].serviceName" --output text 2>/dev/null)

if [ "$USER_SERVICE_EXISTS" = "None" ] || [ -z "$USER_SERVICE_EXISTS" ]; then
  aws ecs create-service \
    --cluster peerprep-cluster \
    --service-name user-service \
    --task-definition user-service-task \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A,$PRIVATE_SUBNET_1B],securityGroups=[$ECS_TASKS_SG_ID],assignPublicIp=DISABLED}" \
    --load-balancers "targetGroupArn=$USER_TG_ARN,containerName=user-service,containerPort=8000" \
    --service-registries "registryArn=$USER_SD_ARN" \
    --health-check-grace-period-seconds 60 \
    --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100" \
    --enable-execute-command \
    --region $AWS_REGION
  echo "✓ User service created"
else
  echo "✓ User service exists"
fi

# Create question service
echo ""
echo "Creating question ECS service..."
QUESTION_SERVICE_EXISTS=$(aws ecs describe-services --region $AWS_REGION \
  --cluster peerprep-cluster \
  --services question-service \
  --query "services[0].serviceName" --output text 2>/dev/null)

if [ "$QUESTION_SERVICE_EXISTS" = "None" ] || [ -z "$QUESTION_SERVICE_EXISTS" ]; then
  aws ecs create-service \
    --cluster peerprep-cluster \
    --service-name question-service \
    --task-definition question-service-task \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A,$PRIVATE_SUBNET_1B],securityGroups=[$ECS_TASKS_SG_ID],assignPublicIp=DISABLED}" \
    --load-balancers "targetGroupArn=$QUESTION_TG_ARN,containerName=question-service,containerPort=8000" \
    --service-registries "registryArn=$QUESTION_SD_ARN" \
    --health-check-grace-period-seconds 60 \
    --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100" \
    --enable-execute-command \
    --region $AWS_REGION
  echo "✓ Question service created"
else
  echo "✓ Question service exists"
fi

# Create matching service
echo ""
echo "Creating matching ECS service..."
MATCHING_SERVICE_EXISTS=$(aws ecs describe-services --region $AWS_REGION \
  --cluster peerprep-cluster \
  --services matching-service \
  --query "services[0].serviceName" --output text 2>/dev/null)

if [ "$MATCHING_SERVICE_EXISTS" = "None" ] || [ -z "$MATCHING_SERVICE_EXISTS" ]; then
  aws ecs create-service \
    --cluster peerprep-cluster \
    --service-name matching-service \
    --task-definition matching-service-task \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A,$PRIVATE_SUBNET_1B],securityGroups=[$ECS_TASKS_SG_ID],assignPublicIp=DISABLED}" \
    --load-balancers "targetGroupArn=$MATCHING_TG_ARN,containerName=matching-service,containerPort=8000" \
    --service-registries "registryArn=$MATCHING_SD_ARN" \
    --health-check-grace-period-seconds 60 \
    --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100" \
    --enable-execute-command \
    --region $AWS_REGION
  echo "✓ Matching service created"
else
  echo "✓ Matching service exists"
fi

# Create history service
echo ""
echo "Creating history ECS service..."
HISTORY_SERVICE_EXISTS=$(aws ecs describe-services --region $AWS_REGION \
  --cluster peerprep-cluster \
  --services history-service \
  --query "services[0].serviceName" --output text 2>/dev/null)

if [ "$HISTORY_SERVICE_EXISTS" = "None" ] || [ -z "$HISTORY_SERVICE_EXISTS" ]; then
  aws ecs create-service \
    --cluster peerprep-cluster \
    --service-name history-service \
    --task-definition history-service-task \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A,$PRIVATE_SUBNET_1B],securityGroups=[$ECS_TASKS_SG_ID],assignPublicIp=DISABLED}" \
    --load-balancers "targetGroupArn=$HISTORY_TG_ARN,containerName=history-service,containerPort=8000" \
    --service-registries "registryArn=$HISTORY_SD_ARN" \
    --health-check-grace-period-seconds 60 \
    --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100" \
    --enable-execute-command \
    --region $AWS_REGION
  echo "✓ History service created"
else
  echo "✓ History service exists"
fi

# Create collaboration service
echo ""
echo "Creating collaboration ECS service..."
COLLAB_SERVICE_EXISTS=$(aws ecs describe-services --region $AWS_REGION \
  --cluster peerprep-cluster \
  --services collaboration-service \
  --query "services[0].serviceName" --output text 2>/dev/null)

if [ "$COLLAB_SERVICE_EXISTS" = "None" ] || [ -z "$COLLAB_SERVICE_EXISTS" ]; then
  aws ecs create-service \
    --cluster peerprep-cluster \
    --service-name collaboration-service \
    --task-definition collaboration-service-task \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A,$PRIVATE_SUBNET_1B],securityGroups=[$ECS_TASKS_SG_ID],assignPublicIp=DISABLED}" \
    --load-balancers "targetGroupArn=$COLLAB_TG_ARN,containerName=collaboration-service,containerPort=8000" \
    --service-registries "registryArn=$COLLAB_SD_ARN" \
    --health-check-grace-period-seconds 60 \
    --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100" \
    --enable-execute-command \
    --region $AWS_REGION
  echo "✓ Collaboration service created"
else
  echo "✓ Collaboration service exists"
fi

# Create chat service
echo ""
echo "Creating chat ECS service..."
CHAT_SERVICE_EXISTS=$(aws ecs describe-services --region $AWS_REGION \
  --cluster peerprep-cluster \
  --services chat-service \
  --query "services[0].serviceName" --output text 2>/dev/null)

if [ "$CHAT_SERVICE_EXISTS" = "None" ] || [ -z "$CHAT_SERVICE_EXISTS" ]; then
  aws ecs create-service \
    --cluster peerprep-cluster \
    --service-name chat-service \
    --task-definition chat-service-task \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A,$PRIVATE_SUBNET_1B],securityGroups=[$ECS_TASKS_SG_ID],assignPublicIp=DISABLED}" \
    --load-balancers "targetGroupArn=$CHAT_TG_ARN,containerName=chat-service,containerPort=8000" \
    --service-registries "registryArn=$CHAT_SD_ARN" \
    --health-check-grace-period-seconds 60 \
    --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100" \
    --enable-execute-command \
    --region $AWS_REGION
  echo "✓ Chat service created"
else
  echo "✓ Chat service exists"
fi

# Create frontend service
echo ""
echo "Creating frontend ECS service..."
FRONTEND_SERVICE_EXISTS=$(aws ecs describe-services --region $AWS_REGION \
  --cluster peerprep-cluster \
  --services frontend \
  --query "services[0].serviceName" --output text 2>/dev/null)

if [ "$FRONTEND_SERVICE_EXISTS" = "None" ] || [ -z "$FRONTEND_SERVICE_EXISTS" ]; then
  aws ecs create-service \
    --cluster peerprep-cluster \
    --service-name frontend \
    --task-definition frontend-task \
    --desired-count 2 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNET_1A,$PRIVATE_SUBNET_1B],securityGroups=[$ECS_TASKS_SG_ID],assignPublicIp=DISABLED}" \
    --load-balancers "targetGroupArn=$FRONTEND_TG_ARN,containerName=frontend,containerPort=80" \
    --health-check-grace-period-seconds 60 \
    --deployment-configuration "maximumPercent=200,minimumHealthyPercent=100" \
    --enable-execute-command \
    --region $AWS_REGION
  echo "✓ Frontend service created"
else
  echo "✓ Frontend service exists"
fi

echo ""
echo "✅ All ECS services created!"

# =========================================
# SECTION 15: FINAL SUMMARY
# =========================================

echo ""
echo "========================================="
echo "🎉 DEPLOYMENT COMPLETE! 🎉"
echo "========================================="
echo ""
echo "Infrastructure Summary:"
echo "----------------------"
echo "VPC ID: $VPC_ID"
echo "Private Subnets: $PRIVATE_SUBNET_1A, $PRIVATE_SUBNET_1B"
echo "Public Subnets: $PUBLIC_SUBNET_1A, $PUBLIC_SUBNET_1B"
echo "RDS Endpoint: $RDS_ENDPOINT"
echo "Redis Endpoint: $REDIS_ENDPOINT"
echo "ALB DNS: $ALB_DNS"
echo "ECS Cluster: peerprep-cluster"
echo "Namespace: peerprep.internal"
echo ""
echo "Security Groups:"
echo "---------------"
echo "ALB SG: $ALB_SG_ID"
echo "ECS Tasks SG: $ECS_TASKS_SG_ID"
echo "RDS SG: $RDS_SG_ID"
echo "Redis SG: $REDIS_SG_ID"
echo ""
echo "Services Deployed:"
echo "-----------------"
echo "✓ frontend (2 tasks)"
echo "✓ user-service (2 tasks)"
echo "✓ question-service (2 tasks)"
echo "✓ matching-service (2 tasks)"
echo "✓ history-service (2 tasks)"
echo "✓ collaboration-service (2 tasks)"
echo "✓ chat-service (2 tasks)"
echo ""
echo "Access your application at:"
echo "http://$ALB_DNS"
echo ""
echo "Next Steps:"
echo "----------"
echo "1. Wait 5-10 minutes for all services to become healthy"
echo "2. Check service status: aws ecs describe-services --cluster peerprep-cluster --services user-service"
echo "3. View logs: aws logs tail /ecs/user-service --follow"
echo "4. Setup Route 53 DNS (optional)"
echo "5. Setup SSL certificate with ACM (optional)"
echo "6. Configure HTTPS listener on ALB (optional)"
echo ""
echo "Cost Estimate: ~\$223/month"
echo ""
echo "========================================="
echo ""

# Save deployment info to file
cat > deployment-info.txt <<EOF
PeerPrep AWS ECS Deployment Information
Generated: $(date)

VPC_ID=$VPC_ID
PRIVATE_SUBNET_1A=$PRIVATE_SUBNET_1A
PRIVATE_SUBNET_1B=$PRIVATE_SUBNET_1B
PUBLIC_SUBNET_1A=$PUBLIC_SUBNET_1A
PUBLIC_SUBNET_1B=$PUBLIC_SUBNET_1B
ALB_SG_ID=$ALB_SG_ID
ECS_TASKS_SG_ID=$ECS_TASKS_SG_ID
RDS_SG_ID=$RDS_SG_ID
REDIS_SG_ID=$REDIS_SG_ID
RDS_ENDPOINT=$RDS_ENDPOINT
REDIS_ENDPOINT=$REDIS_ENDPOINT
ALB_ARN=$ALB_ARN
ALB_DNS=$ALB_DNS
NAMESPACE_ID=$NAMESPACE_ID
ECS_EXECUTION_ROLE_ARN=$ECS_EXECUTION_ROLE_ARN
ECS_TASK_ROLE_ARN=$ECS_TASK_ROLE_ARN

Application URL: http://$ALB_DNS
EOF

echo "✅ Deployment information saved to deployment-info.txt"
echo ""
