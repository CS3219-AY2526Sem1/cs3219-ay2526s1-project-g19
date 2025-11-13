#!/bin/bash
set -e

# =========================================
# PeerPrep Complete AWS Cleanup Script
# =========================================

echo "========================================="
echo "PeerPrep AWS Complete Cleanup"
echo "========================================="
echo ""
echo "⚠️  WARNING: This will delete ALL PeerPrep resources!"
echo "This includes:"
echo "  - ECS Services and Cluster"
echo "  - RDS Database (with data)"
echo "  - ElastiCache Redis (with data)"
echo "  - Load Balancer and Target Groups"
echo "  - ECR Repositories (with images)"
echo "  - VPC and all networking"
echo "  - Security Groups"
echo "  - IAM Roles"
echo "  - CloudWatch Logs"
echo ""
read -p "Are you sure? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Cleanup cancelled."
  exit 0
fi

# Configuration
export AWS_REGION=ap-southeast-1
export PROJECT_NAME=peerprep
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo ""
echo "Starting cleanup in region: $AWS_REGION"
echo "Project: $PROJECT_NAME"
echo ""

# Helper function to check if resource exists
resource_exists() {
  local output="$1"
  [ "$output" != "None" ] && [ -n "$output" ] && [ "$output" != "null" ]
}

# =========================================
# SECTION 1: DELETE ECS SERVICES
# =========================================

echo "========================================="
echo "Step 1: Deleting ECS Services"
echo "========================================="

CLUSTER_NAME="peerprep-cluster"
services=("frontend" "user-service" "question-service" "matching-service" "history-service" "collaboration-service" "chat-service")

# Check if cluster exists
CLUSTER_EXISTS=$(aws ecs describe-clusters --region $AWS_REGION \
  --clusters $CLUSTER_NAME \
  --query "clusters[0].clusterName" --output text 2>/dev/null)

if resource_exists "$CLUSTER_EXISTS"; then
  for service in "${services[@]}"; do
    echo ""
    echo "Deleting $service..."
    
    SERVICE_EXISTS=$(aws ecs describe-services --region $AWS_REGION \
      --cluster $CLUSTER_NAME \
      --services $service \
      --query "services[0].serviceName" --output text 2>/dev/null)
    
    if resource_exists "$SERVICE_EXISTS"; then
      # Scale down to 0 first
      aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $service \
        --desired-count 0 \
        --region $AWS_REGION >/dev/null 2>&1
      
      # Delete service
      aws ecs delete-service \
        --cluster $CLUSTER_NAME \
        --service $service \
        --force \
        --region $AWS_REGION >/dev/null 2>&1
      
      echo "✓ $service deleted"
    else
      echo "⊘ $service does not exist"
    fi
  done
  
  echo ""
  echo "Waiting for services to be deleted (this may take 1-2 minutes)..."
  sleep 30
  
  # Wait for all services to be deleted
  for service in "${services[@]}"; do
    echo "  Checking $service..."
    RETRY=0
    while [ $RETRY -lt 12 ]; do
      SERVICE_STATUS=$(aws ecs describe-services --region $AWS_REGION \
        --cluster $CLUSTER_NAME \
        --services $service \
        --query "services[0].status" --output text 2>/dev/null)
      
      if [ "$SERVICE_STATUS" = "None" ] || [ -z "$SERVICE_STATUS" ] || [ "$SERVICE_STATUS" = "INACTIVE" ]; then
        echo "  ✓ $service fully deleted"
        break
      fi
      
      sleep 5
      RETRY=$((RETRY+1))
    done
  done
else
  echo "⊘ ECS Cluster does not exist, skipping service deletion"
fi

echo ""
echo "✅ ECS services deleted"

# =========================================
# SECTION 2: DELETE SERVICE DISCOVERY
# =========================================

echo ""
echo "========================================="
echo "Step 2: Deleting Service Discovery"
echo "========================================="

# Get namespace ID
NAMESPACE_ID=$(aws servicediscovery list-namespaces --region $AWS_REGION \
  --filters Name=TYPE,Values=DNS_PRIVATE,Condition=EQ \
  --query "Namespaces[?Name=='peerprep.internal'].Id" \
  --output text 2>/dev/null)

if resource_exists "$NAMESPACE_ID"; then
  # Delete services
  sd_services=("user-service" "question-service" "matching-service" "history-service" "collaboration-service" "chat-service")
  
  for sd_service in "${sd_services[@]}"; do
    echo "Deleting service discovery for $sd_service..."
    
    SD_SERVICE_ID=$(aws servicediscovery list-services --region $AWS_REGION \
      --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID,Condition=EQ \
      --query "Services[?Name=='$sd_service'].Id" \
      --output text 2>/dev/null)
    
    if resource_exists "$SD_SERVICE_ID"; then
      aws servicediscovery delete-service \
        --id $SD_SERVICE_ID \
        --region $AWS_REGION >/dev/null 2>&1
      echo "✓ Service discovery for $sd_service deleted"
    else
      echo "⊘ Service discovery for $sd_service does not exist"
    fi
  done
  
  # Delete namespace
  echo ""
  echo "Deleting namespace..."
  aws servicediscovery delete-namespace \
    --id $NAMESPACE_ID \
    --region $AWS_REGION >/dev/null 2>&1
  echo "✓ Namespace deleted"
else
  echo "⊘ Service discovery namespace does not exist"
fi

echo ""
echo "✅ Service discovery cleaned up"

# =========================================
# SECTION 3: DELETE ALB AND TARGET GROUPS
# =========================================

echo ""
echo "========================================="
echo "Step 3: Deleting Load Balancer"
echo "========================================="

# Delete ALB
ALB_ARN=$(aws elbv2 describe-load-balancers --region $AWS_REGION \
  --names peerprep-alb \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text 2>/dev/null)

if resource_exists "$ALB_ARN"; then
  echo "Deleting Application Load Balancer..."
  aws elbv2 delete-load-balancer \
    --load-balancer-arn $ALB_ARN \
    --region $AWS_REGION
  echo "✓ ALB deletion initiated"
  
  echo "Waiting for ALB to be deleted (this takes ~2 minutes)..."
  sleep 60
else
  echo "⊘ ALB does not exist"
fi

# Delete target groups
echo ""
echo "Deleting target groups..."
target_groups=("peerprep-frontend-tg" "peerprep-user-tg" "peerprep-question-tg" "peerprep-matching-tg" "peerprep-history-tg" "peerprep-collab-tg" "peerprep-chat-tg")

for tg in "${target_groups[@]}"; do
  TG_ARN=$(aws elbv2 describe-target-groups --region $AWS_REGION \
    --names $tg \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text 2>/dev/null)
  
  if resource_exists "$TG_ARN"; then
    aws elbv2 delete-target-group \
      --target-group-arn $TG_ARN \
      --region $AWS_REGION 2>/dev/null
    echo "✓ $tg deleted"
  else
    echo "⊘ $tg does not exist"
  fi
done

echo ""
echo "✅ Load balancer and target groups deleted"

# =========================================
# SECTION 4: DELETE ECS CLUSTER
# =========================================

echo ""
echo "========================================="
echo "Step 4: Deleting ECS Cluster"
echo "========================================="

if resource_exists "$CLUSTER_EXISTS"; then
  echo "Deleting ECS cluster..."
  aws ecs delete-cluster \
    --cluster $CLUSTER_NAME \
    --region $AWS_REGION >/dev/null 2>&1
  echo "✓ ECS cluster deleted"
else
  echo "⊘ ECS cluster does not exist"
fi

echo ""
echo "✅ ECS cluster deleted"

# =========================================
# SECTION 5: DELETE RDS
# =========================================

echo ""
echo "========================================="
echo "Step 5: Deleting RDS Database"
echo "========================================="

RDS_INSTANCE="peerprep-db"

RDS_EXISTS=$(aws rds describe-db-instances --region $AWS_REGION \
  --db-instance-identifier $RDS_INSTANCE \
  --query "DBInstances[0].DBInstanceIdentifier" \
  --output text 2>/dev/null)

if resource_exists "$RDS_EXISTS"; then
  echo "Deleting RDS instance (skip final snapshot)..."
  aws rds delete-db-instance \
    --db-instance-identifier $RDS_INSTANCE \
    --skip-final-snapshot \
    --region $AWS_REGION >/dev/null 2>&1
  echo "✓ RDS deletion initiated (this takes ~5-10 minutes)"
  
  echo "Waiting for RDS to be deleted..."
  aws rds wait db-instance-deleted \
    --db-instance-identifier $RDS_INSTANCE \
    --region $AWS_REGION 2>/dev/null && echo "✓ RDS deleted" || echo "⚠ RDS deletion in progress..."
else
  echo "⊘ RDS instance does not exist"
fi

# Delete DB subnet group
echo ""
echo "Deleting DB subnet group..."
DB_SUBNET_GROUP_EXISTS=$(aws rds describe-db-subnet-groups --region $AWS_REGION \
  --db-subnet-group-name peerprep-db-subnet-group \
  --query "DBSubnetGroups[0].DBSubnetGroupName" \
  --output text 2>/dev/null)

if resource_exists "$DB_SUBNET_GROUP_EXISTS"; then
  aws rds delete-db-subnet-group \
    --db-subnet-group-name peerprep-db-subnet-group \
    --region $AWS_REGION 2>/dev/null
  echo "✓ DB subnet group deleted"
else
  echo "⊘ DB subnet group does not exist"
fi

echo ""
echo "✅ RDS cleaned up"

# =========================================
# SECTION 6: DELETE ELASTICACHE REDIS
# =========================================

echo ""
echo "========================================="
echo "Step 6: Deleting ElastiCache Redis"
echo "========================================="

REDIS_ID="peerprep-redis"

REDIS_EXISTS=$(aws elasticache describe-replication-groups --region $AWS_REGION \
  --replication-group-id $REDIS_ID \
  --query "ReplicationGroups[0].ReplicationGroupId" \
  --output text 2>/dev/null)

if resource_exists "$REDIS_EXISTS"; then
  echo "Deleting Redis replication group..."
  aws elasticache delete-replication-group \
    --replication-group-id $REDIS_ID \
    --region $AWS_REGION >/dev/null 2>&1
  echo "✓ Redis deletion initiated (this takes ~5 minutes)"
  
  echo "Waiting for Redis to be deleted..."
  sleep 30
  
  RETRY=0
  while [ $RETRY -lt 20 ]; do
    REDIS_STATUS=$(aws elasticache describe-replication-groups --region $AWS_REGION \
      --replication-group-id $REDIS_ID \
      --query "ReplicationGroups[0].Status" \
      --output text 2>/dev/null)
    
    if [ "$REDIS_STATUS" = "None" ] || [ -z "$REDIS_STATUS" ]; then
      echo "✓ Redis deleted"
      break
    fi
    
    sleep 15
    RETRY=$((RETRY+1))
  done
else
  echo "⊘ Redis replication group does not exist"
fi

# Delete Redis subnet group
echo ""
echo "Deleting Redis subnet group..."
REDIS_SUBNET_GROUP_EXISTS=$(aws elasticache describe-cache-subnet-groups --region $AWS_REGION \
  --cache-subnet-group-name peerprep-redis-subnet-group \
  --query "CacheSubnetGroups[0].CacheSubnetGroupName" \
  --output text 2>/dev/null)

if resource_exists "$REDIS_SUBNET_GROUP_EXISTS"; then
  aws elasticache delete-cache-subnet-group \
    --cache-subnet-group-name peerprep-redis-subnet-group \
    --region $AWS_REGION 2>/dev/null
  echo "✓ Redis subnet group deleted"
else
  echo "⊘ Redis subnet group does not exist"
fi

echo ""
echo "✅ ElastiCache cleaned up"

# =========================================
# SECTION 7: DELETE ECR REPOSITORIES
# =========================================

echo ""
echo "========================================="
echo "Step 7: Deleting ECR Repositories"
echo "========================================="

ecr_services=("frontend" "user-service" "question-service" "matching-service" "history-service" "collaboration-service" "chat-service")

for service in "${ecr_services[@]}"; do
  REPO_EXISTS=$(aws ecr describe-repositories --region $AWS_REGION \
    --repository-names peerprep/$service \
    --query "repositories[0].repositoryName" \
    --output text 2>/dev/null)
  
  if resource_exists "$REPO_EXISTS"; then
    aws ecr delete-repository \
      --repository-name peerprep/$service \
      --force \
      --region $AWS_REGION >/dev/null 2>&1
    echo "✓ ECR repository peerprep/$service deleted"
  else
    echo "⊘ ECR repository peerprep/$service does not exist"
  fi
done

echo ""
echo "✅ ECR repositories deleted"

# =========================================
# SECTION 8: DELETE SECURITY GROUPS
# =========================================

echo ""
echo "========================================="
echo "Step 8: Deleting Security Groups"
echo "========================================="

# Get VPC ID
VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION \
  --filters "Name=tag:Name,Values=${PROJECT_NAME}-vpc" \
  --query "Vpcs[0].VpcId" \
  --output text 2>/dev/null)

if resource_exists "$VPC_ID"; then
  # Delete security groups (must be done after all resources using them are deleted)
  echo "Waiting for resources to fully release security groups..."
  sleep 30
  
  security_groups=("peerprep-redis-sg" "peerprep-rds-sg" "peerprep-ecs-tasks-sg" "peerprep-alb-sg")
  
  for sg_name in "${security_groups[@]}"; do
    echo ""
    echo "Deleting $sg_name..."
    
    SG_ID=$(aws ec2 describe-security-groups --region $AWS_REGION \
      --filters "Name=group-name,Values=$sg_name" "Name=vpc-id,Values=$VPC_ID" \
      --query "SecurityGroups[0].GroupId" \
      --output text 2>/dev/null)
    
    if resource_exists "$SG_ID"; then
      # Remove all ingress rules first
      aws ec2 describe-security-groups --region $AWS_REGION \
        --group-ids $SG_ID \
        --query "SecurityGroups[0].IpPermissions" \
        --output json > /tmp/sg-rules.json 2>/dev/null
      
      if [ -s /tmp/sg-rules.json ] && [ "$(cat /tmp/sg-rules.json)" != "[]" ]; then
        aws ec2 revoke-security-group-ingress \
          --group-id $SG_ID \
          --ip-permissions file:///tmp/sg-rules.json \
          --region $AWS_REGION 2>/dev/null
      fi
      
      # Try to delete
      RETRY=0
      while [ $RETRY -lt 10 ]; do
        aws ec2 delete-security-group \
          --group-id $SG_ID \
          --region $AWS_REGION 2>/dev/null && break
        
        sleep 5
        RETRY=$((RETRY+1))
      done
      
      echo "✓ $sg_name deleted"
    else
      echo "⊘ $sg_name does not exist"
    fi
  done
  
  rm -f /tmp/sg-rules.json
else
  echo "⊘ VPC does not exist, skipping security groups"
fi

echo ""
echo "✅ Security groups deleted"

# =========================================
# SECTION 9: DELETE VPC NETWORKING
# =========================================

echo ""
echo "========================================="
echo "Step 9: Deleting VPC and Networking"
echo "========================================="

if resource_exists "$VPC_ID"; then
  # Delete NAT Gateway
  echo "Deleting NAT Gateway..."
  NAT_GW_ID=$(aws ec2 describe-nat-gateways --region $AWS_REGION \
    --filter "Name=tag:Name,Values=${PROJECT_NAME}-nat" "Name=state,Values=available,pending,deleting" \
    --query "NatGateways[0].NatGatewayId" \
    --output text 2>/dev/null)
  
  if resource_exists "$NAT_GW_ID"; then
    aws ec2 delete-nat-gateway \
      --nat-gateway-id $NAT_GW_ID \
      --region $AWS_REGION >/dev/null 2>&1
    echo "✓ NAT Gateway deletion initiated"
    
    echo "Waiting for NAT Gateway to be deleted (this takes 2-5 minutes)..."
    aws ec2 wait nat-gateway-deleted \
      --nat-gateway-ids $NAT_GW_ID \
      --region $AWS_REGION 2>/dev/null && echo "✓ NAT Gateway deleted" || echo "⚠ NAT Gateway deletion in progress..."
  else
    echo "⊘ NAT Gateway does not exist"
  fi
  
  # Release Elastic IP
  echo ""
  echo "Releasing Elastic IP..."
  EIP_ALLOC_ID=$(aws ec2 describe-addresses --region $AWS_REGION \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-eip" \
    --query "Addresses[0].AllocationId" \
    --output text 2>/dev/null)
  
  if resource_exists "$EIP_ALLOC_ID"; then
    aws ec2 release-address \
      --allocation-id $EIP_ALLOC_ID \
      --region $AWS_REGION 2>/dev/null
    echo "✓ Elastic IP released"
  else
    echo "⊘ Elastic IP does not exist or not tagged"
  fi
  
  # Delete route tables
  echo ""
  echo "Deleting route tables..."
  
  # Public route table
  PUBLIC_RT_ID=$(aws ec2 describe-route-tables --region $AWS_REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PROJECT_NAME}-public-rt" \
    --query "RouteTables[0].RouteTableId" \
    --output text 2>/dev/null)
  
  if resource_exists "$PUBLIC_RT_ID"; then
    # Disassociate subnets
    ASSOCIATIONS=$(aws ec2 describe-route-tables --region $AWS_REGION \
      --route-table-ids $PUBLIC_RT_ID \
      --query "RouteTables[0].Associations[?!Main].RouteTableAssociationId" \
      --output text 2>/dev/null)
    
    for assoc in $ASSOCIATIONS; do
      aws ec2 disassociate-route-table \
        --association-id $assoc \
        --region $AWS_REGION 2>/dev/null
    done
    
    aws ec2 delete-route-table \
      --route-table-id $PUBLIC_RT_ID \
      --region $AWS_REGION 2>/dev/null
    echo "✓ Public route table deleted"
  else
    echo "⊘ Public route table does not exist"
  fi
  
  # Private route table
  PRIVATE_RT_ID=$(aws ec2 describe-route-tables --region $AWS_REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${PROJECT_NAME}-private-rt" \
    --query "RouteTables[0].RouteTableId" \
    --output text 2>/dev/null)
  
  if resource_exists "$PRIVATE_RT_ID"; then
    # Disassociate subnets
    ASSOCIATIONS=$(aws ec2 describe-route-tables --region $AWS_REGION \
      --route-table-ids $PRIVATE_RT_ID \
      --query "RouteTables[0].Associations[?!Main].RouteTableAssociationId" \
      --output text 2>/dev/null)
    
    for assoc in $ASSOCIATIONS; do
      aws ec2 disassociate-route-table \
        --association-id $assoc \
        --region $AWS_REGION 2>/dev/null
    done
    
    aws ec2 delete-route-table \
      --route-table-id $PRIVATE_RT_ID \
      --region $AWS_REGION 2>/dev/null
    echo "✓ Private route table deleted"
  else
    echo "⊘ Private route table does not exist"
  fi
  
  # Detach and delete Internet Gateway
  echo ""
  echo "Deleting Internet Gateway..."
  IGW_ID=$(aws ec2 describe-internet-gateways --region $AWS_REGION \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-igw" \
    --query "InternetGateways[0].InternetGatewayId" \
    --output text 2>/dev/null)
  
  if resource_exists "$IGW_ID"; then
    aws ec2 detach-internet-gateway \
      --internet-gateway-id $IGW_ID \
      --vpc-id $VPC_ID \
      --region $AWS_REGION 2>/dev/null
    
    aws ec2 delete-internet-gateway \
      --internet-gateway-id $IGW_ID \
      --region $AWS_REGION 2>/dev/null
    echo "✓ Internet Gateway deleted"
  else
    echo "⊘ Internet Gateway does not exist"
  fi
  
  # Delete subnets
  echo ""
  echo "Deleting subnets..."
  subnet_names=("private-1a" "private-1b" "public-1a" "public-1b")
  
  for subnet_name in "${subnet_names[@]}"; do
    SUBNET_ID=$(aws ec2 describe-subnets --region $AWS_REGION \
      --filters "Name=tag:Name,Values=${PROJECT_NAME}-${subnet_name}" "Name=vpc-id,Values=$VPC_ID" \
      --query "Subnets[0].SubnetId" \
      --output text 2>/dev/null)
    
    if resource_exists "$SUBNET_ID"; then
      aws ec2 delete-subnet \
        --subnet-id $SUBNET_ID \
        --region $AWS_REGION 2>/dev/null
      echo "✓ Subnet ${subnet_name} deleted"
    else
      echo "⊘ Subnet ${subnet_name} does not exist"
    fi
  done
  
  # Delete VPC
  echo ""
  echo "Deleting VPC..."
  sleep 5
  aws ec2 delete-vpc \
    --vpc-id $VPC_ID \
    --region $AWS_REGION 2>/dev/null
  echo "✓ VPC deleted"
else
  echo "⊘ VPC does not exist"
fi

echo ""
echo "✅ VPC and networking deleted"

# =========================================
# SECTION 10: DELETE IAM ROLES
# =========================================

echo ""
echo "========================================="
echo "Step 10: Deleting IAM Roles"
echo "========================================="

# Delete ECS Task Execution Role
echo "Deleting ECS Task Execution Role..."
ROLE_EXISTS=$(aws iam get-role --role-name ecsTaskExecutionRole \
  --query "Role.RoleName" \
  --output text 2>/dev/null)

if resource_exists "$ROLE_EXISTS"; then
  # Detach policies
  aws iam detach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>/dev/null
  
  # Delete role
  aws iam delete-role \
    --role-name ecsTaskExecutionRole 2>/dev/null
  echo "✓ ECS Task Execution Role deleted"
else
  echo "⊘ ECS Task Execution Role does not exist"
fi

# Delete ECS Task Role
echo ""
echo "Deleting ECS Task Role..."
ROLE_EXISTS=$(aws iam get-role --role-name ecsTaskRole \
  --query "Role.RoleName" \
  --output text 2>/dev/null)

if resource_exists "$ROLE_EXISTS"; then
  aws iam delete-role \
    --role-name ecsTaskRole 2>/dev/null
  echo "✓ ECS Task Role deleted"
else
  echo "⊘ ECS Task Role does not exist"
fi

echo ""
echo "✅ IAM roles deleted"

# =========================================
# SECTION 11: DELETE CLOUDWATCH LOGS
# =========================================

echo ""
echo "========================================="
echo "Step 11: Deleting CloudWatch Log Groups"
echo "========================================="

log_groups=("/ecs/frontend" "/ecs/user-service" "/ecs/question-service" "/ecs/matching-service" "/ecs/history-service" "/ecs/collaboration-service" "/ecs/chat-service")

for log_group in "${log_groups[@]}"; do
  LOG_EXISTS=$(aws logs describe-log-groups --region $AWS_REGION \
    --log-group-name-prefix $log_group \
    --query "logGroups[0].logGroupName" \
    --output text 2>/dev/null)
  
  if resource_exists "$LOG_EXISTS"; then
    aws logs delete-log-group \
      --log-group-name $log_group \
      --region $AWS_REGION 2>/dev/null
    echo "✓ Log group $log_group deleted"
  else
    echo "⊘ Log group $log_group does not exist"
  fi
done

echo ""
echo "✅ CloudWatch logs deleted"

# =========================================
# FINAL SUMMARY
# =========================================

echo ""
echo "========================================="
echo "🎉 CLEANUP COMPLETE! 🎉"
echo "========================================="
echo ""
echo "All PeerPrep resources have been deleted:"
echo ""
echo "✓ ECS Services and Cluster"
echo "✓ Service Discovery"
echo "✓ Application Load Balancer"
echo "✓ Target Groups"
echo "✓ RDS PostgreSQL Database"
echo "✓ ElastiCache Redis"
echo "✓ ECR Repositories"
echo "✓ Security Groups"
echo "✓ VPC and Networking (NAT, IGW, Subnets)"
echo "✓ IAM Roles"
echo "✓ CloudWatch Log Groups"
echo ""
echo "Note: Some resources may take a few more minutes to fully delete."
echo "You can verify by checking the AWS Console."
echo ""
echo "========================================="
echo ""

# Delete the deployment info file if it exists
rm -f deployment-info.txt 2>/dev/null

echo "✅ Cleanup script completed successfully!"