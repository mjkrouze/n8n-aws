#!/bin/bash

set -e

echo "🛑 Stopping N8n service..."

# Get stack outputs
CLUSTER_NAME=$(aws cloudformation describe-stacks \
    --stack-name N8nStack \
    --query 'Stacks[0].Outputs[?OutputKey==`ClusterName`].OutputValue' \
    --output text)

SERVICE_NAME=$(aws cloudformation describe-stacks \
    --stack-name N8nStack \
    --query 'Stacks[0].Outputs[?OutputKey==`ServiceName`].OutputValue' \
    --output text)

echo "📡 Scaling service to 0 tasks..."
aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --desired-count 0 \
    --no-cli-pager

echo "⏳ Waiting for service to scale down..."
aws ecs wait services-stable \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME"

echo "✅ N8n service stopped!"
echo ""
echo "💰 Service is now scaled to 0 - no compute charges while stopped"
echo "To start again, run: ./scripts/start.sh"