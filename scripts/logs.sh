#!/bin/bash

set -e

echo "📋 Viewing N8n logs..."

# Get the log group name
LOG_GROUP="/ecs/n8n"

echo "🔍 Tailing logs from $LOG_GROUP"
echo "Press Ctrl+C to stop viewing logs"
echo ""

# Stream logs in real time
aws logs tail "$LOG_GROUP" --follow