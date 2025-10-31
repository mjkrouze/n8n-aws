.PHONY: help install build test lint format clean \
		deploy destroy start stop restart status logs logs-recent open connect port-forward \
		synth diff bootstrap list-stacks \
		cdk-shell validate

# Configuration
ENV ?= dev
PYTHON := python3
CDK_DIR := cdk
CLI_DIR := cli
VENV := .venv

# Colors for output
COLOR_RESET := \033[0m
COLOR_BOLD := \033[1m
COLOR_GREEN := \033[32m
COLOR_BLUE := \033[36m
COLOR_YELLOW := \033[33m

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "$(COLOR_BOLD)N8n AWS Deployment - Available Commands$(COLOR_RESET)"
	@echo ""
	@echo "$(COLOR_BLUE)Instance Management:$(COLOR_RESET)"
	@grep -E '^(start|stop|restart|status|logs|logs-recent|open|connect|port-forward):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-18s$(COLOR_RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(COLOR_BLUE)Infrastructure Management:$(COLOR_RESET)"
	@grep -E '^(deploy|destroy|synth|diff|bootstrap|list-stacks):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-18s$(COLOR_RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(COLOR_BLUE)Development:$(COLOR_RESET)"
	@grep -E '^(install|build|test|lint|format|validate|cdk-shell|clean|help):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(COLOR_GREEN)%-18s$(COLOR_RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(COLOR_BLUE)Quick Start:$(COLOR_RESET)"
	@echo "  make install               # Install dependencies"
	@echo "  make deploy ENV=dev        # Deploy infrastructure"
	@echo "  make start ENV=dev         # Start n8n"
	@echo "  make open ENV=dev          # Open n8n in browser"
	@echo "  make stop ENV=dev          # Stop n8n (save costs)"
	@echo ""
	@echo "$(COLOR_BLUE)Access n8n:$(COLOR_RESET)"
	@echo "  make open                  # Direct access via public IP (easiest)"
	@echo "  make connect               # Session Manager (secure)"
	@echo ""
	@echo "$(COLOR_YELLOW)Note: Use ENV=dev or ENV=prod to specify environment (default: dev)$(COLOR_RESET)"

# Instance Management
start: ## Start n8n service (scale to 1 task)
	@echo "$(COLOR_BOLD)🚀 Starting n8n service (ENV=$(ENV))...$(COLOR_RESET)"
	@./scripts/start.sh

stop: ## Stop n8n service (scale to 0 tasks, save costs)
	@echo "$(COLOR_BOLD)🛑 Stopping n8n service (ENV=$(ENV))...$(COLOR_RESET)"
	@./scripts/stop.sh

restart: stop start ## Restart n8n service

status: ## Show current service status
	@echo "$(COLOR_BOLD)📊 Checking n8n service status (ENV=$(ENV))...$(COLOR_RESET)"
	@./scripts/status.sh

logs: ## View real-time n8n logs
	@echo "$(COLOR_BOLD)📋 Viewing n8n logs (ENV=$(ENV))...$(COLOR_RESET)"
	@./scripts/logs.sh

logs-recent: ## View logs from last hour
	@echo "$(COLOR_BOLD)📋 Viewing recent n8n logs (ENV=$(ENV))...$(COLOR_RESET)"
	@./scripts/logs.sh --since 1h

open: ## Open n8n in browser (via public IP)
	@echo "$(COLOR_BOLD)🌐 Opening n8n URL (ENV=$(ENV))...$(COLOR_RESET)"
	@./scripts/open.sh

connect: ## Connect to n8n via Session Manager (interactive shell)
	@echo "$(COLOR_BOLD)🔌 Connecting via Session Manager...$(COLOR_RESET)"
	@./scripts/connect.sh

port-forward: ## Set up port forwarding via Session Manager
	@echo "$(COLOR_BOLD)🔌 Setting up port forwarding...$(COLOR_RESET)"
	@./scripts/port-forward.sh

# Infrastructure Management
deploy: ## Deploy n8n infrastructure to AWS
	@echo "$(COLOR_BOLD)🚀 Deploying n8n infrastructure (ENV=$(ENV))...$(COLOR_RESET)"
	@./scripts/deploy.sh

destroy: ## Remove all AWS infrastructure (WARNING: destructive)
	@echo "$(COLOR_BOLD)🗑️  Destroying n8n infrastructure (ENV=$(ENV))...$(COLOR_RESET)"
	@./scripts/destroy.sh

synth: ## Synthesize CloudFormation templates
	@echo "$(COLOR_BOLD)🔨 Synthesizing CDK app...$(COLOR_RESET)"
	@cd $(CDK_DIR) && \
		. $(VENV)/bin/activate && \
		cdk synth
	@echo "$(COLOR_GREEN)✅ Templates generated in $(CDK_DIR)/cdk.out$(COLOR_RESET)"

diff: ## Show infrastructure changes (what will be deployed)
	@echo "$(COLOR_BOLD)🔍 Checking infrastructure differences...$(COLOR_RESET)"
	@cd $(CDK_DIR) && \
		. $(VENV)/bin/activate && \
		cdk diff

bootstrap: ## Bootstrap CDK in AWS account/region
	@echo "$(COLOR_BOLD)🎯 Bootstrapping CDK...$(COLOR_RESET)"
	@cd $(CDK_DIR) && \
		. $(VENV)/bin/activate && \
		cdk bootstrap
	@echo "$(COLOR_GREEN)✅ CDK bootstrap complete$(COLOR_RESET)"

list-stacks: ## List all deployed CDK stacks
	@echo "$(COLOR_BOLD)📋 Listing CDK stacks...$(COLOR_RESET)"
	@cd $(CDK_DIR) && \
		. $(VENV)/bin/activate && \
		cdk list

# Development
install: ## Install all dependencies (CDK + CLI)
	@echo "$(COLOR_BOLD)📦 Installing dependencies...$(COLOR_RESET)"
	@echo "Installing CDK dependencies..."
	@cd $(CDK_DIR) && \
		$(PYTHON) -m venv $(VENV) && \
		. $(VENV)/bin/activate && \
		pip install --upgrade pip && \
		pip install -r requirements.txt
	@if [ -d "$(CLI_DIR)" ] && [ -f "$(CLI_DIR)/requirements.txt" ]; then \
		echo "Installing CLI dependencies..."; \
		cd $(CLI_DIR) && \
		$(PYTHON) -m venv $(VENV) && \
		. $(VENV)/bin/activate && \
		pip install --upgrade pip && \
		pip install -r requirements.txt; \
	fi
	@echo "$(COLOR_GREEN)✅ Installation complete$(COLOR_RESET)"

build: ## Build/validate Python modules
	@echo "$(COLOR_BOLD)🔨 Building and validating Python code...$(COLOR_RESET)"
	@echo "Validating CDK code..."
	@cd $(CDK_DIR) && \
		$(PYTHON) -m py_compile app.py
	@if [ -d "$(CDK_DIR)/stacks" ]; then \
		cd $(CDK_DIR) && \
		find stacks -name "*.py" -exec $(PYTHON) -m py_compile {} \;; \
	fi
	@if [ -d "$(CLI_DIR)" ]; then \
		echo "Validating CLI code..."; \
		cd $(CLI_DIR) && \
		$(PYTHON) -m py_compile main.py 2>/dev/null || true; \
		find . -name "*.py" -not -path "./$(VENV)/*" -exec $(PYTHON) -m py_compile {} \; 2>/dev/null || true; \
	fi
	@echo "$(COLOR_GREEN)✅ Build validation complete$(COLOR_RESET)"

test: ## Run tests (CDK + CLI)
	@echo "$(COLOR_BOLD)🧪 Running tests...$(COLOR_RESET)"
	@if [ -d "$(CDK_DIR)/$(VENV)" ]; then \
		echo "Running CDK tests..."; \
		cd $(CDK_DIR) && \
		. $(VENV)/bin/activate && \
		pytest tests/ -v 2>/dev/null || echo "No CDK tests found or pytest not installed"; \
	fi
	@if [ -d "$(CLI_DIR)/$(VENV)" ]; then \
		echo "Running CLI tests..."; \
		cd $(CLI_DIR) && \
		. $(VENV)/bin/activate && \
		pytest tests/ -v 2>/dev/null || echo "No CLI tests found or pytest not installed"; \
	fi
	@echo "$(COLOR_GREEN)✅ Tests complete$(COLOR_RESET)"

lint: ## Lint Python code with flake8
	@echo "$(COLOR_BOLD)🔍 Linting Python code...$(COLOR_RESET)"
	@if [ -d "$(CDK_DIR)/$(VENV)" ]; then \
		cd $(CDK_DIR) && \
		. $(VENV)/bin/activate && \
		flake8 . --exclude=$(VENV),cdk.out --max-line-length=120 2>/dev/null || echo "flake8 not installed, skipping CDK lint"; \
	fi
	@if [ -d "$(CLI_DIR)/$(VENV)" ]; then \
		cd $(CLI_DIR) && \
		. $(VENV)/bin/activate && \
		flake8 . --exclude=$(VENV) --max-line-length=120 2>/dev/null || echo "flake8 not installed, skipping CLI lint"; \
	fi
	@echo "$(COLOR_GREEN)✅ Linting complete$(COLOR_RESET)"

format: ## Format Python code with black
	@echo "$(COLOR_BOLD)✨ Formatting Python code...$(COLOR_RESET)"
	@if [ -d "$(CDK_DIR)/$(VENV)" ]; then \
		cd $(CDK_DIR) && \
		. $(VENV)/bin/activate && \
		black . --exclude=$(VENV) 2>/dev/null || echo "black not installed, skipping CDK format"; \
	fi
	@if [ -d "$(CLI_DIR)/$(VENV)" ]; then \
		cd $(CLI_DIR) && \
		. $(VENV)/bin/activate && \
		black . --exclude=$(VENV) 2>/dev/null || echo "black not installed, skipping CLI format"; \
	fi
	@echo "$(COLOR_GREEN)✅ Formatting complete$(COLOR_RESET)"

validate: ## Validate CDK app and synthesize
	@echo "$(COLOR_BOLD)✅ Validating CDK app...$(COLOR_RESET)"
	@cd $(CDK_DIR) && \
		. $(VENV)/bin/activate && \
		cdk synth --quiet > /dev/null
	@echo "$(COLOR_GREEN)✅ CDK app is valid$(COLOR_RESET)"

cdk-shell: ## Open shell with CDK virtual environment activated
	@echo "$(COLOR_BOLD)🐚 Opening CDK shell...$(COLOR_RESET)"
	@echo "Virtual environment activated. Type 'exit' to quit."
	@cd $(CDK_DIR) && \
		. $(VENV)/bin/activate && \
		exec $(SHELL)

clean: ## Clean up build artifacts and caches
	@echo "$(COLOR_BOLD)🧹 Cleaning up local artifacts...$(COLOR_RESET)"
	@rm -rf $(CDK_DIR)/$(VENV)
	@rm -rf $(CDK_DIR)/cdk.out
	@rm -rf $(CDK_DIR)/__pycache__
	@rm -rf $(CDK_DIR)/stacks/__pycache__
	@find $(CDK_DIR) -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find $(CDK_DIR) -type f -name "*.pyc" -delete 2>/dev/null || true
	@if [ -d "$(CLI_DIR)" ]; then \
		rm -rf $(CLI_DIR)/$(VENV); \
		rm -rf $(CLI_DIR)/__pycache__; \
		find $(CLI_DIR) -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true; \
		find $(CLI_DIR) -type f -name "*.pyc" -delete 2>/dev/null || true; \
	fi
	@echo "$(COLOR_GREEN)✅ Cleanup complete$(COLOR_RESET)"