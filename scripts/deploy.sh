#!/bin/bash

set -e

echo "🚀 Deploying N8n infrastructure..."

cd cdk

# Install dependencies if needed
if [ ! -d ".venv" ]; then
    echo "📦 Setting up Python virtual environment..."
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
else
    source .venv/bin/activate
fi

# Bootstrap CDK if needed (only needs to be done once per account/region)
echo "🔧 Bootstrapping CDK..."
cdk bootstrap

# Deploy the stack
echo "🏗️  Deploying N8n stack..."
cdk deploy --require-approval never

echo "✅ Deployment complete!"
echo ""
echo "To start N8n, run: ./scripts/start.sh"
echo "To stop N8n, run: ./scripts/stop.sh"