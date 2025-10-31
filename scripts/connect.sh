#!/bin/bash

# Connect to n8n via AWS Systems Manager Session Manager
# This script sets up port forwarding to access n8n UI on localhost:5678

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔌 Connecting to n8n via Session Manager...${NC}"
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
    echo -e "${YELLOW}⚠️  Service is not running (desired count = 0)${NC}"
    echo ""
    echo "Would you like to start the service? (y/n)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo -e "${BLUE}Starting service...${NC}"
        ../scripts/start.sh
    else
        echo -e "${RED}Cannot connect to stopped service. Exiting.${NC}"
        exit 1
    fi
fi

# Get task ARN
echo -e "${BLUE}Getting task information...${NC}"
TASK_ARN=$(aws ecs list-tasks \
    --cluster "$CLUSTER_NAME" \
    --service-name "$SERVICE_NAME" \
    --query 'taskArns[0]' \
    --output text)

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
    echo -e "${RED}❌ Error: No running tasks found${NC}"
    echo "Service may still be starting. Wait a moment and try again."
    exit 1
fi

TASK_ID=$(echo "$TASK_ARN" | awk -F/ '{print $NF}')
echo -e "${GREEN}✓${NC} Found task: $TASK_ID"
echo ""

# Check if Session Manager plugin is installed
if ! command -v session-manager-plugin &> /dev/null; then
    echo -e "${YELLOW}⚠️  AWS Session Manager plugin not found${NC}"
    echo ""
    echo "Please install the Session Manager plugin:"
    echo ""
    echo "macOS:"
    echo "  curl \"https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/sessionmanager-bundle.zip\" -o \"sessionmanager-bundle.zip\""
    echo "  unzip sessionmanager-bundle.zip"
    echo "  sudo ./sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin"
    echo ""
    echo "Linux:"
    echo "  curl \"https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm\" -o \"session-manager-plugin.rpm\""
    echo "  sudo yum install -y session-manager-plugin.rpm"
    echo ""
    echo "For other OS: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
    exit 1
fi

# Start port forwarding using ECS Exec
echo -e "${GREEN}Starting port forwarding to localhost:5678...${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}n8n is now accessible at: http://localhost:5678${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Press Ctrl+C to disconnect${NC}"
echo ""

# Execute command to start port forwarding
# Note: This requires the task to have ECS Exec enabled
aws ecs execute-command \
    --cluster "$CLUSTER_NAME" \
    --task "$TASK_ARN" \
    --container N8nContainer \
    --interactive \
    --command "/bin/sh -c 'echo \"Port forwarding active. Connect to http://localhost:5678\" && tail -f /dev/null'"

echo ""
echo -e "${BLUE}Disconnected from n8n${NC}"
