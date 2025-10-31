# n8n on AWS

Deploy n8n workflow automation on AWS ECS Fargate with infrastructure-as-code, CLI management tools, and "scale to zero" cost optimization.

## Overview

This project provides a complete solution for deploying and managing n8n (workflow automation tool) on AWS. It includes:

- **Infrastructure as Code**: AWS CDK (Python) for reproducible deployments
- **CLI Management Tools**: Simple commands to start, stop, and manage your n8n instance
- **Workflow Version Control**: Store workflows as JSON files in git
- **Ultra Cost-Optimized**: ~$4-5/month for typical usage (no ALB, no NAT Gateway)
- **Data Persistence**: EFS storage ensures your workflows and data survive restarts
- **Flexible Access**: Direct via public IP or secure via Session Manager
- **Backup & Restore**: Automated backups to S3 with easy restore

## Quick Start

```bash
# 1. Install dependencies
make install

# 2. Deploy infrastructure (takes 5-10 minutes)
make deploy ENV=dev

# 3. Start n8n
make start ENV=dev

# 4. Stop when done to save costs
make stop ENV=dev
```

## Features

- **Ultra Cost-Effective**: ~$4-5/month for typical usage (couple times per week)
- **Easy Deploy**: One-command deployment with AWS CDK
- **Start/Stop**: Simple scripts to control n8n service
- **Flexible Access**: Direct access via public IP or Session Manager
- **Secure**: Security groups with least privilege access control
- **Persistent**: EFS storage for workflows and data
- **Monitoring**: CloudWatch logs and metrics
- **Workflow-as-Code**: Version control workflows with git
- **Backup & Restore**: S3-based backup system

## Architecture

```
Internet → Load Balancer → ECS Fargate (n8n) → EFS (Data Storage)
                                ↓
                         DynamoDB (State) + S3 (Backups)
```

The system uses:
- **ECS Fargate**: Serverless container hosting
- **Application Load Balancer**: Public web access with health checks
- **EFS**: Persistent storage for n8n data and workflows
- **VPC**: Isolated network with public/private subnets
- **DynamoDB**: Deployment state and workflow metadata tracking
- **S3**: Backup storage
- **CloudWatch**: Centralized logging and monitoring

**[Read Full Architecture Documentation →](docs/architecture.md)**

## Prerequisites

- AWS Account with administrative access
- [AWS CLI](https://aws.amazon.com/cli/) configured
- [AWS CDK CLI](https://docs.aws.amazon.com/cdk/latest/guide/cli.html) installed (`npm install -g aws-cdk`)
- Python 3.8+
- Make (usually pre-installed)

## Documentation

- **[User Guide](docs/user-guide.md)** - Complete guide to using this system
  - Installation and setup
  - Managing your n8n instance
  - Working with workflows
  - Backup and restore
  - Troubleshooting
  - Cost management

- **[Architecture Documentation](docs/architecture.md)** - Technical deep dive
  - System architecture and components
  - Infrastructure design decisions
  - Security architecture
  - Scalability and performance
  - Disaster recovery

- **[Project Instructions](claude.md)** - Development guidelines
  - Project structure
  - Implementation roadmap
  - AWS best practices

## Common Commands

### Instance Management

```bash
make start ENV=dev           # Start n8n service
make stop ENV=dev            # Stop n8n service (save costs)
make restart ENV=dev         # Restart service
make status ENV=dev          # Check service status
make logs ENV=dev            # View real-time logs
make open ENV=dev            # Open n8n in browser (via public IP)
make connect ENV=dev         # Connect via Session Manager (interactive)
make port-forward ENV=dev    # Set up port forwarding
```

### Infrastructure Management

```bash
make deploy ENV=dev          # Deploy infrastructure
make destroy ENV=dev         # Remove all infrastructure
make diff ENV=dev            # Preview infrastructure changes
make synth ENV=dev           # Generate CloudFormation templates
```

### Workflow Management

```bash
make deploy-workflow WORKFLOW=workflows/file.json ENV=dev  # Deploy one workflow
make deploy-workflows ENV=dev                               # Deploy all workflows
make export-workflows ENV=dev                               # Export workflows from n8n
make validate-workflows                                     # Validate workflow JSON
```

### Backup & Restore

```bash
make backup ENV=dev                          # Create backup
make list-backups ENV=dev                    # List available backups
make restore BACKUP_ID=20231101-120000 ENV=dev  # Restore from backup
```

### Development

```bash
make install                 # Install all dependencies
make build                   # Build/validate code
make test                    # Run tests
make lint                    # Lint code
make clean                   # Clean build artifacts
make help                    # Show all available commands
```

## Cost Breakdown

### Running (1 task active - ~20 hours/month)
- ECS Fargate: ~$1/month (20h @ $0.05/hour)
- EFS: ~$3/month (10GB storage)
- Other (CloudWatch, etc.): ~$0.50/month
- **Total: ~$4-5/month** 🎉

### Stopped (0 tasks)
- EFS: ~$3/month (storage only)
- **Total: ~$3/month**

**Cost Optimization Highlights**:
- **No Application Load Balancer** saves ~$17/month
- **No NAT Gateway** saves ~$32/month
- **Start/stop when needed** saves ~$35/month vs always-on
- Access via **public IP** (free) or **Session Manager** (free)
- **Total savings: ~$84/month compared to traditional always-on architecture**

**[Learn more about cost management →](docs/user-guide.md#cost-management)**

## Accessing n8n

This deployment uses a **cost-optimized architecture without an Application Load Balancer**. You can access n8n in two ways:

### Option 1: Direct Access via Public IP (Recommended)

The simplest method - just get the public IP and open it in your browser:

```bash
make open ENV=dev
```

This will:
1. Get the task's public IP address
2. Open `http://<public-ip>:5678` in your browser

**Note**: The public IP changes each time the task restarts, but the script automatically finds the current IP.

### Option 2: AWS Session Manager (More Secure)

For enhanced security, use Session Manager for encrypted access:

```bash
# Interactive shell access
make connect ENV=dev

# Port forwarding (advanced)
make port-forward ENV=dev
```

**Prerequisites**: Install the Session Manager plugin:
```bash
# macOS
brew install --cask session-manager-plugin

# Linux
# See: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
```

**[Learn more about access methods →](docs/user-guide.md#accessing-n8n)**

## Project Structure

```
n8n-aws/
├── cdk/                    # AWS CDK infrastructure (Python)
│   ├── stacks/            # CDK stack definitions
│   │   ├── network_stack.py       # VPC, subnets, security groups
│   │   ├── storage_stack.py       # EFS file system
│   │   ├── compute_stack.py       # ECS cluster and service
│   │   └── loadbalancer_stack.py  # Application load balancer
│   └── app.py             # CDK app entry point
├── cli/                    # CLI tool for managing n8n (Python)
│   ├── commands/          # Command implementations
│   │   ├── start.py
│   │   ├── stop.py
│   │   ├── deploy.py
│   │   └── backup.py
│   └── utils/             # Helper utilities
├── workflows/              # n8n workflow definitions (JSON)
├── config/                 # Environment-specific configurations
│   ├── dev.json
│   └── prod.json
├── scripts/                # Shell scripts for Makefile
├── docs/                   # Documentation
│   ├── architecture.md    # Technical architecture
│   └── user-guide.md      # User documentation
├── Makefile               # Main entry point for all operations
└── README.md              # This file
```

## Configuration

Configuration files in `config/` directory define environment-specific settings:

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
      "Project": "n8n-automation"
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

**[Learn more about configuration →](docs/user-guide.md#configuration)**

## Security

- Security groups restrict traffic to necessary ports (ECS only accepts from ALB)
- Load balancer provides controlled public access
- EFS encryption in transit enabled
- IAM roles follow least privilege principle
- Secrets managed via AWS Secrets Manager
- Simplified architecture suitable for low-risk, personal/development use

**[Read security architecture →](docs/architecture.md#security-architecture)**

## Troubleshooting

### Service Won't Start
```bash
make logs ENV=dev
```

### Can't Access n8n URL
```bash
make status ENV=dev
# Check that tasks are healthy and running
```

### High Costs
```bash
# Ensure service is stopped when not in use
make stop ENV=dev
```

**[View complete troubleshooting guide →](docs/user-guide.md#monitoring-and-troubleshooting)**

## Workflow as Code

Store and version control your workflows:

```bash
# 1. Create workflows in n8n UI
# 2. Export to files
make export-workflows ENV=dev

# 3. Commit to git
git add workflows/
git commit -m "Added customer notification workflow"

# 4. Deploy to other environments
make deploy-workflows ENV=prod
```

**[Learn more about workflow management →](docs/user-guide.md#working-with-workflows)**

## Multi-Environment Support

Deploy separate dev, staging, and production environments:

```bash
# Development
make deploy ENV=dev
make start ENV=dev

# Production
make deploy ENV=prod
make start ENV=prod
```

Each environment has isolated AWS resources and configuration.

## Future Enhancements

- [ ] Automated daily backups via EventBridge
- [ ] CloudWatch dashboards and alarms
- [ ] External database support (RDS PostgreSQL)
- [ ] Horizontal scaling (multiple tasks)
- [ ] Custom domain and SSL certificate
- [ ] Workflow testing framework
- [ ] CI/CD pipeline integration
- [ ] Slack/email notifications for workflow failures

## Contributing

This is a personal project, but suggestions and improvements are welcome. Please open an issue to discuss proposed changes.

## Resources

- [n8n Documentation](https://docs.n8n.io/)
- [n8n API Documentation](https://docs.n8n.io/api/)
- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

## License

This project is provided as-is for educational and personal use.

## Getting Started

Ready to deploy n8n on AWS? Start with the **[User Guide](docs/user-guide.md)** for step-by-step instructions.

For technical details and architecture decisions, see the **[Architecture Documentation](docs/architecture.md)**.

---

**Quick Start Reminder:**
```bash
make install && make deploy ENV=dev && make start ENV=dev
```
