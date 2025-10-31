#!/bin/bash

# Get n8n URL and open in browser
# Without ALB, this gets the task's public IP

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌐 Getting n8n URL...${NC}"
echo ""

# Get cluster and service name from CDK outputs
CLUSTER_NAME=$(aws cloudformation describe-stacks \
    --stack-name N8nStack \
    --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' \
    --output text 2>/dev/null)

SERVICE_NAME=$(aws cloudformation describe-stacks \
    --stack-name N8nStack \
    --query 'Stacks[0].Outputs[?OutputKey==`ServiceName`].OutputValue' \
    --output text 2>/dev/null)

if [ -z "$CLUSTER_NAME" ] || [ -z "$SERVICE_NAME" ]; then
    echo -e "${RED}❌ Error: Could not find n8n stack${NC}"
    exit 1
fi

# Check if service is running
RUNNING_COUNT=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --query 'services[0].runningCount' \
    --output text)

if [ "$RUNNING_COUNT" = "0" ]; then
    echo -e "${YELLOW}⚠️  Service is not running${NC}"
    echo "Run 'make start' first."
    exit 1
fi

# Get task ARN
TASK_ARN=$(aws ecs list-tasks \
    --cluster "$CLUSTER_NAME" \
    --service-name "$SERVICE_NAME" \
    --query 'taskArns[0]' \
    --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
    echo -e "${RED}❌ Error: No running tasks found${NC}"
    exit 1
fi

# Get the task's ENI (Elastic Network Interface) ID
ENI_ID=$(aws ecs describe-tasks \
    --cluster "$CLUSTER_NAME" \
    --tasks "$TASK_ARN" \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text)

# Get the public IP
PUBLIC_IP=$(aws ec2 describe-network-interfaces \
    --network-interface-ids "$ENI_ID" \
    --query 'NetworkInterfaces[0].Association.PublicIp' \
    --output text)

if [ -z "$PUBLIC_IP" ] || [ "$PUBLIC_IP" = "None" ]; then
    echo -e "${RED}❌ Error: Could not find public IP${NC}"
    echo "Make sure the task has a public IP assigned."
    exit 1
fi

N8N_URL="http://${PUBLIC_IP}:5678"

echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  n8n URL: ${N8N_URL}${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Try to open in browser
if command -v open &> /dev/null; then
    # macOS
    echo -e "${BLUE}Opening in browser...${NC}"
    open "$N8N_URL"
elif command -v xdg-open &> /dev/null; then
    # Linux
    echo -e "${BLUE}Opening in browser...${NC}"
    xdg-open "$N8N_URL"
else
    echo -e "${YELLOW}Copy and paste this URL into your browser:${NC}"
    echo -e "${GREEN}${N8N_URL}${NC}"
fi
