#!/bin/bash

set -e

echo "🗑️  Destroying N8n infrastructure..."

# Stop the service first
echo "🛑 Stopping service before destruction..."
./scripts/stop.sh

cd cdk

# Activate virtual environment
source .venv/bin/activate

# Destroy the stack
echo "💥 Destroying N8n stack..."
cdk destroy --force

echo "✅ Infrastructure destroyed!"
echo ""
echo "⚠️  Note: This removes all infrastructure including data in EFS"