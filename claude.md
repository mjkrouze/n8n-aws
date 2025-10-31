# n8n AWS Deployment & Management Project

## Project Overview

This project deploys and manages n8n (workflow automation tool) on AWS using ECS Fargate, with supporting infrastructure including EFS for data persistence, DynamoDB for state management, and S3 for backups. It includes CLI tools for managing the n8n instance and deploying workflows from code.

## Tech Stack

- **Infrastructure**: AWS CDK (Python)
- **Compute**: ECS Fargate
- **Storage**: EFS (for n8n data persistence), S3 (for backups)
- **State Management**: DynamoDB (for deployment state, workflow metadata)
- **CLI**: Python
- **Workflows**: JSON files in version control

## Project Structure

```
n8n-aws-deployment/
├── cdk/                    # AWS CDK infrastructure code (Python)
│   ├── stacks/            # Individual CDK stack definitions
│   └── .venv/             # Python virtual environment (not in git)
├── cli/                    # CLI tool for managing n8n instance
│   ├── commands/          # CLI command implementations
│   ├── utils/             # Helper utilities (AWS, n8n API, config)
│   └── .venv/             # Python virtual environment (not in git)
├── workflows/              # n8n workflow definitions (JSON)
├── config/                 # Environment-specific configurations
├── scripts/                # Shell scripts for Makefile operations
└── Makefile               # Main entry point for all operations
```

### Key Directories

- **cdk/**: Contains all infrastructure-as-code using AWS CDK with Python
  - Modular stack definitions (storage, DynamoDB, ECS, load balancer)
  - Each stack focuses on a specific infrastructure component

- **cli/**: Python-based CLI tool for n8n management
  - Commands for start, stop, status, workflow deployment, backups
  - Utilities for AWS SDK (boto3), n8n API client, configuration

- **workflows/**: Version-controlled n8n workflow definitions
  - JSON files representing workflow configurations
  - Can be deployed to n8n instance via CLI

- **config/**: Environment-specific configuration files (dev, prod)
  - JSON format with AWS settings, stack names, resource sizing

## AWS Infrastructure Best Practices

### General Principles

**Modularity**: Organize infrastructure into logical, reusable stacks that can be deployed and managed independently. Each stack should have a single, well-defined responsibility.

**Security**:
- Use IAM roles with least privilege principle
- Enable encryption at rest and in transit for all data stores
- Implement security groups with minimal necessary access (principle of least privilege)
- Store sensitive credentials in AWS Secrets Manager, not in environment variables
- Use VPC endpoints where possible to keep traffic within AWS network
- Enable CloudWatch logging for all services

**Cost Optimization**:
- Design for "scale to zero" where appropriate (e.g., ECS desired count = 0 when not in use)
- Use appropriate sizing for resources (don't over-provision)
- Implement lifecycle policies for data retention and archival
- Consider using Spot instances/Fargate Spot for non-production workloads
- Tag all resources for cost allocation and tracking

**Reliability**:
- Design for failure - assume any component can fail
- Implement health checks and automated recovery
- Use CloudWatch alarms for monitoring critical metrics
- Enable backups for stateful services
- Document recovery procedures

**Observability**:
- Centralize logs in CloudWatch Logs
- Use structured logging where possible
- Implement distributed tracing for debugging
- Create dashboards for key metrics
- Set up alerts for anomalous behavior

**Infrastructure as Code**:
- All infrastructure should be defined in CDK code
- Use environment-specific configuration files
- Never make manual changes in the AWS console
- Version control all infrastructure code
- Test infrastructure changes in dev before deploying to prod

## CLI Commands

All operations are performed via Makefile targets for consistency and ease of use.

### Instance Management
```bash
# Start n8n instance (set ECS desired count to 1)
make start ENV=dev

# Stop n8n instance (set ECS desired count to 0)
make stop ENV=dev

# Check instance status
make status ENV=dev

# Restart instance
make restart ENV=dev
```

### Workflow Management
```bash
# Deploy single workflow
make deploy-workflow WORKFLOW=workflows/workflow-1.json ENV=dev

# Deploy all workflows
make deploy-workflows ENV=dev

# Export workflows from n8n to local files
make export-workflows ENV=dev

# Validate workflows (check JSON syntax and structure)
make validate-workflows
```

### Infrastructure Management
```bash
# Deploy CDK stacks
make deploy ENV=dev

# Deploy specific stack
make deploy-stack STACK=NetworkStack ENV=dev

# Destroy infrastructure
make destroy ENV=dev

# Diff infrastructure changes
make diff ENV=dev

# Synthesize CloudFormation templates
make synth ENV=dev
```

### Database & Backup
```bash
# Backup n8n database to S3
make backup ENV=dev

# Restore from backup
make restore BACKUP_ID=20231101-120000 ENV=dev

# List available backups
make list-backups ENV=dev
```

### Development & Testing
```bash
# Install all dependencies (CDK + CLI)
make install

# Build CLI and CDK
make build

# Run tests
make test

# Lint code
make lint

# Clean build artifacts
make clean

# Format code
make format
```

### Logs & Monitoring
```bash
# Tail n8n container logs
make logs ENV=dev

# View logs from last hour
make logs-recent ENV=dev

# Open n8n in browser
make open ENV=dev
```

## Implementation Steps

### Phase 1: Infrastructure Setup
1. Initialize CDK project with Python
   - Set up virtual environment
   - Install aws-cdk-lib and constructs
   - Create app.py and stacks directory structure
2. Design and implement core infrastructure stacks
   - Define stack boundaries and dependencies
   - Implement networking, compute, storage, and other required services
   - Follow modular design principles
3. Configure security and access controls
   - Set up IAM roles and policies
   - Configure security groups
   - Set up Secrets Manager if needed
4. Implement monitoring and logging
   - CloudWatch log groups
   - Alarms and metrics
5. Test and validate deployment

### Phase 2: CLI Development
1. Set up CLI project structure with Python
   - Create commands, utils directories
   - Set up virtual environment
   - Create main.py entry point
2. Implement AWS SDK clients using boto3 (ECS, DynamoDB, S3)
3. Create n8n API client using requests library
4. Implement start/stop commands
5. Implement status command
6. Test instance management

### Phase 3: Workflow Management
1. Implement workflow deployment command
2. Add workflow validation using jsonschema
3. Implement workflow export command
4. Add DynamoDB tracking for workflows
5. Implement backup command using boto3
6. Test full workflow lifecycle

### Phase 4: Enhancement & Documentation
1. Add error handling and retry logic
2. Implement logging using Python logging module
3. Add configuration validation using pydantic or dataclasses
4. Write comprehensive README
5. Add workflow examples
6. Create troubleshooting guide

## Key Considerations

### Architecture Decisions
As you build out the infrastructure, consider:

**Data Persistence**: How will n8n data be stored?
- Options: EFS, RDS, S3, or combination
- Trade-offs: cost, performance, backup complexity, operational overhead

**Networking**: How should the application be accessed?
- Public vs private subnets
- Load balancer configuration
- VPC design and subnet strategy

**Compute**: What compute model makes sense?
- ECS Fargate vs EC2
- Task sizing and scaling strategy
- Desired count management for cost control

**State Management**: How to track deployments and workflows?
- DynamoDB tables for metadata
- S3 for backups and exports
- Version control for workflows

### Development Workflow
1. Start with minimal viable infrastructure
2. Test thoroughly in dev environment
3. Document architectural decisions
4. Iterate and add features incrementally
5. Keep configuration separate from code

### n8n API Integration
The n8n REST API endpoints we'll use:
- `GET /workflows` - List all workflows
- `POST /workflows` - Create workflow
- `GET /workflows/:id` - Get workflow by ID
- `PUT /workflows/:id` - Update workflow
- `DELETE /workflows/:id` - Delete workflow
- `POST /workflows/:id/activate` - Activate workflow

Authentication: Basic Auth or API Key (configured in n8n settings)

### Workflow Version Control
- Store workflows as JSON files in `workflows/` directory
- Include workflow metadata in filename or separate manifest
- Use git for version control
- Track workflow hashes in DynamoDB to detect changes
- Support rollback by keeping workflow history

## Configuration File Format

Configuration files should be JSON format and stored in the `config/` directory. Use separate files for each environment (dev, prod, staging, etc.).

Example structure:
```json
{
  "environment": "dev",
  "aws": {
    "region": "us-east-1",
    "account": "123456789012"
  },
  "stack": {
    "prefix": "n8n-dev",
    "tags": {
      "Environment": "dev",
      "Project": "n8n-automation",
      "ManagedBy": "CDK"
    }
  },
  "application": {
    "version": "latest",
    "port": 5678,
    "resources": {
      "memory": "2048",
      "cpu": "1024"
    }
  }
}
```

### Configuration Best Practices
- Never commit sensitive data (passwords, keys) to configuration files
- Use descriptive names for resources that include the environment
- Keep dev and prod configurations clearly separated
- Document all configuration options
- Validate configuration on load

## Testing Strategy

1. **Infrastructure Tests**: CDK snapshot tests using pytest
2. **CLI Unit Tests**: Test individual command logic using pytest
3. **Integration Tests**: Test AWS service interactions using moto (AWS mocking)
4. **End-to-End Tests**: Deploy and manage test workflows

Testing tools:
- `pytest`: Test framework
- `pytest-cdk`: CDK-specific testing utilities
- `moto`: Mock AWS services for testing
- `coverage`: Code coverage reporting

## Useful AWS CDK Patterns

### Stack Dependencies
```python
# Define dependencies between stacks
database_stack = DatabaseStack(app, 'Database', env=env)
compute_stack = ComputeStack(app, 'Compute',
    database=database_stack.database,
    env=env
)
compute_stack.add_dependency(database_stack)
```

### Environment-Specific Configuration
```python
# Load configuration from JSON files
import json

env_name = app.node.try_get_context('environment') or 'dev'
with open(f'config/{env_name}.json') as f:
    config = json.load(f)

# Use configuration in stacks
stack = MyStack(app, 'MyStack',
    config=config,
    env=cdk.Environment(
        account=config['aws']['account'],
        region=config['aws']['region']
    )
)
```

### Outputs for Cross-Stack References
```python
from aws_cdk import CfnOutput

# Export values for use by other stacks or CLI
CfnOutput(self, 'ClusterName',
    value=cluster.cluster_name,
    description='ECS Cluster name',
    export_name=f'{stack_name}-ClusterName'
)
```

### Security Best Practices
```python
# Use Secrets Manager for sensitive data
from aws_cdk import aws_secretsmanager as secretsmanager

secret = secretsmanager.Secret(self, 'AppSecret',
    generate_secret_string=secretsmanager.SecretStringGenerator(
        secret_string_template=json.dumps({'username': 'admin'}),
        generate_string_key='password'
    )
)

# Reference secrets in ECS task definitions
container.add_environment('PUBLIC_VAR', 'value')
container.add_secret('SECRET_VAR',
    ecs.Secret.from_secrets_manager(secret, 'password')
)
```

## Troubleshooting Common Issues

### General Debugging Approach
1. **Check CloudWatch Logs**: Always start with the logs
   ```bash
   make logs ENV=dev
   ```

2. **Verify Service Status**: Check the current state of resources
   ```bash
   make status ENV=dev
   ```

3. **Review Security Groups**: Ensure proper network connectivity
   - Check that security groups allow required traffic
   - Verify source/destination configurations
   - Look for port and protocol mismatches

4. **Validate IAM Permissions**: Confirm roles have necessary permissions
   - Check ECS task role for application permissions
   - Check ECS execution role for AWS service access
   - Review CloudWatch Logs permissions

5. **Check Resource Quotas**: Verify AWS service limits
   - ECS task limits
   - VPC limits (NAT Gateways, Elastic IPs, etc.)
   - CloudWatch Logs retention settings

### Cost Management
If costs are higher than expected:
```bash
# Stop non-essential services
make stop ENV=dev

# Review running resources
aws ecs list-services --cluster <cluster-name>
aws ec2 describe-nat-gateways --filter "Name=state,Values=available"
```

## Makefile Implementation Details

The Makefile should:
- Default to `ENV=dev` if not specified
- Validate required environment variables before operations
- Use `.PHONY` targets appropriately
- Include help text accessible via `make help`
- Color-code output for better readability
- Implement error handling and cleanup
- Support parallel execution where safe

Example Makefile structure:
```makefile
.PHONY: help install build deploy start stop status

ENV ?= dev
CONFIG_FILE = config/$(ENV).json
PYTHON := python3
VENV := .venv

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $1, $2}'

install: ## Install dependencies
	@echo "Installing CDK dependencies..."
	cd cdk && $(PYTHON) -m venv $(VENV) && \
		. $(VENV)/bin/activate && \
		pip install -r requirements.txt
	@echo "Installing CLI dependencies..."
	cd cli && $(PYTHON) -m venv $(VENV) && \
		. $(VENV)/bin/activate && \
		pip install -r requirements.txt

build: ## Build/validate Python modules
	@echo "Validating Python syntax..."
	cd cdk && $(PYTHON) -m py_compile app.py stacks/*.py
	cd cli && $(PYTHON) -m py_compile main.py commands/*.py utils/*.py

start: ## Start n8n instance
	@echo "Starting n8n instance in $(ENV) environment..."
	cd cli && $(PYTHON) main.py start --env $(ENV)

# ... other targets
```

## Future Enhancements

- Multi-environment support with environment-specific configs
- Automated workflow testing before deployment
- Slack/email notifications for workflow failures
- CloudWatch dashboards for monitoring
- CI/CD pipeline for automated deployments
- Workflow dry-run/validation mode
- Support for n8n community nodes

## Commands for Claude Code

When working on this project, you can ask me to:
- "Set up the CDK infrastructure for [specific stack]"
- "Create the CLI command for [operation]"
- "Implement the n8n API client"
- "Add a new workflow to the workflows directory"
- "Create the Makefile with all targets"
- "Deploy the infrastructure to [environment]"
- "Test the workflow deployment process"

Example commands:
```bash
# Quick start
make install
make build
make deploy ENV=dev
make start ENV=dev

# Daily workflow
make deploy-workflows ENV=dev
make status ENV=dev

# End of day
make stop ENV=dev
```

## Resources

- [n8n Documentation](https://docs.n8n.io/)
- [n8n API Documentation](https://docs.n8n.io/api/)
- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)