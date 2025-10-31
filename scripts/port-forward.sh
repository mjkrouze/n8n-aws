#!/bin/bash

# Port forward to n8n via AWS Systems Manager Session Manager
# This creates an SSH tunnel to access n8n UI on localhost:5678

set -e

# Configuration
LOCAL_PORT="${LOCAL_PORT:-5678}"
REMOTE_PORT=5678

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔌 Setting up port forwarding to n8n...${NC}"
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
    echo -e "${RED}❌ Error: Could not find n8n stack. Is it deployed?${NC}"
    echo "Run 'make deploy' first."
    exit 1
fi

echo -e "${GREEN}✓${NC} Found cluster: $CLUSTER_NAME"
echo -e "${GREEN}✓${NC} Found service: $SERVICE_NAME"
echo ""

# Check if service is running
RUNNING_COUNT=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --query 'services[0].runningCount' \
    --output text)

if [ "$RUNNING_COUNT" = "0" ]; then
    echo -e "${YELLOW}⚠️  Service is not running${NC}"
    echo ""
    read -p "Start the service now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Starting service...${NC}"
        $(dirname "$0")/start.sh
        echo ""
        echo -e "${BLUE}Waiting for service to be healthy...${NC}"
        sleep 10
    else
        echo -e "${RED}Cannot connect to stopped service. Exiting.${NC}"
        exit 1
    fi
fi

# Get task information
echo -e "${BLUE}Getting task information...${NC}"
TASK_ARN=$(aws ecs list-tasks \
    --cluster "$CLUSTER_NAME" \
    --service-name "$SERVICE_NAME" \
    --query 'taskArns[0]' \
    --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
    echo -e "${RED}❌ Error: No running tasks found${NC}"
    exit 1
fi

TASK_ID=$(echo "$TASK_ARN" | awk -F/ '{print $NF}')

# Get the task's ENI (Elastic Network Interface) ID
echo -e "${BLUE}Getting network information...${NC}"
ENI_ID=$(aws ecs describe-tasks \
    --cluster "$CLUSTER_NAME" \
    --tasks "$TASK_ARN" \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text)

if [ -z "$ENI_ID" ]; then
    echo -e "${RED}❌ Error: Could not find network interface${NC}"
    exit 1
fi

# Get the public IP
PUBLIC_IP=$(aws ec2 describe-network-interfaces \
    --network-interface-ids "$ENI_ID" \
    --query 'NetworkInterfaces[0].Association.PublicIp' \
    --output text)

echo -e "${GREEN}✓${NC} Task ID: $TASK_ID"
echo -e "${GREEN}✓${NC} Public IP: $PUBLIC_IP"
echo ""

# Check if Session Manager plugin is installed
if ! command -v session-manager-plugin &> /dev/null; then
    echo -e "${YELLOW}⚠️  AWS Session Manager plugin not found${NC}"
    echo ""
    echo "Install it with:"
    echo ""
    echo "  macOS:   brew install --cask session-manager-plugin"
    echo "  Linux:   See https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
    echo ""
    echo -e "${BLUE}Alternative: Direct access via public IP${NC}"
    echo -e "${GREEN}Try accessing: http://${PUBLIC_IP}:5678${NC}"
    echo ""
    exit 1
fi

# Use ECS Exec to create interactive session with port forwarding
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Starting interactive session with port forwarding${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}After connection, run this command:${NC}"
echo -e "${YELLOW}  socat TCP-LISTEN:5678,reuseaddr,fork TCP:localhost:5678${NC}"
echo ""
echo -e "Or access directly via: ${GREEN}http://${PUBLIC_IP}:5678${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+D to exit${NC}"
echo ""

aws ecs execute-command \
    --cluster "$CLUSTER_NAME" \
    --task "$TASK_ARN" \
    --container N8nContainer \
    --interactive \
    --command "/bin/sh"
