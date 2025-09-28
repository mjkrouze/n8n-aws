.PHONY: help deploy start stop status logs destroy clean

# Default target
help:
	@echo "N8n AWS Deployment - Available targets:"
	@echo ""
	@echo "  deploy    - Deploy n8n infrastructure to AWS"
	@echo "  start     - Start the n8n service (scale to 1 task)"
	@echo "  stop      - Stop the n8n service (scale to 0 tasks)"
	@echo "  status    - Show current service status"
	@echo "  logs      - View real-time n8n logs"
	@echo "  destroy   - Remove all AWS infrastructure"
	@echo "  clean     - Clean up local build artifacts"
	@echo ""
	@echo "Quick start:"
	@echo "  make deploy    # Deploy infrastructure"
	@echo "  make start     # Start n8n"
	@echo "  make status    # Check status and get URL"
	@echo "  make stop      # Stop n8n (save costs)"

deploy:
	@echo "🚀 Deploying n8n infrastructure..."
	@./scripts/deploy.sh

start:
	@echo "🚀 Starting n8n service..."
	@./scripts/start.sh

stop:
	@echo "🛑 Stopping n8n service..."
	@./scripts/stop.sh

status:
	@echo "📊 Checking n8n service status..."
	@./scripts/status.sh

logs:
	@echo "📋 Viewing n8n logs..."
	@./scripts/logs.sh

destroy:
	@echo "🗑️  Destroying n8n infrastructure..."
	@./scripts/destroy.sh

clean:
	@echo "🧹 Cleaning up local artifacts..."
	@rm -rf cdk/.venv
	@rm -rf cdk/cdk.out
	@rm -rf cdk/__pycache__
	@rm -rf cdk/stacks/__pycache__
	@echo "✅ Local cleanup complete"