#!/bin/bash

set -e

echo "🚀 Starting N8n service..."

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

echo "📡 Scaling service to 1 task..."
aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --desired-count 1 \
    --no-cli-pager

echo "⏳ Waiting for service to become stable..."
aws ecs wait services-stable \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME"

echo "✅ N8n is now running!"
echo "🌐 Access N8n at: $N8N_URL"
echo ""
echo "To view logs, run: ./scripts/logs.sh"
echo "To stop the service, run: ./scripts/stop.sh"