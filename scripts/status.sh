#!/bin/bash

set -e

echo "📊 N8n Service Status"
echo "===================="

# Check if stack exists
if ! aws cloudformation describe-stacks --stack-name N8nStack &>/dev/null; then
    echo "❌ N8n stack not deployed"
    echo ""
    echo "To deploy, run: ./scripts/deploy.sh"
    exit 0
fi

# Get stack outputs
CLUSTER_NAME=$(aws cloudformation describe-stacks \
    --stack-name N8nStack \
    --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' \
    --output text)

SERVICE_NAME=$(aws cloudformation describe-stacks \
    --stack-name N8nStack \
    --query 'Stacks[0].Outputs[?OutputKey==`ServiceName`].OutputValue' \
    --output text)

N8N_URL=$(aws cloudformation describe-stacks \
    --stack-name N8nStack \
    --query 'Stacks[0].Outputs[?OutputKey==`N8nURL`].OutputValue' \
    --output text)

# Get service status
SERVICE_STATUS=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --query 'services[0].status' \
    --output text)

DESIRED_COUNT=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --query 'services[0].desiredCount' \
    --output text)

RUNNING_COUNT=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --query 'services[0].runningCount' \
    --output text)

echo "🏗️  Stack: N8nStack (deployed)"
echo "📡 Cluster: $CLUSTER_NAME"
echo "🎯 Service: $SERVICE_NAME"
echo "📊 Status: $SERVICE_STATUS"
echo "🔢 Desired Tasks: $DESIRED_COUNT"
echo "🏃 Running Tasks: $RUNNING_COUNT"

if [ "$RUNNING_COUNT" -gt 0 ]; then
    echo "✅ N8n is RUNNING"
    echo "🌐 URL: $N8N_URL"
else
    echo "⏹️  N8n is STOPPED"
    echo ""
    echo "To start: ./scripts/start.sh"
fi

echo ""
echo "Available commands:"
echo "  ./scripts/start.sh   - Start N8n"
echo "  ./scripts/stop.sh    - Stop N8n"
echo "  ./scripts/logs.sh    - View logs"
echo "  ./scripts/destroy.sh - Destroy infrastructure"