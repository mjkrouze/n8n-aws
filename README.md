# N8n on AWS ECS

Deploy n8n workflow automation tool on Amazon ECS using AWS CDK with Python.

## Features

- 🚀 **Easy Deploy**: One command deployment with CDK
- ⚡ **Start/Stop**: Simple scripts to control n8n service
- 💰 **Cost Effective**: Scale to 0 when not in use
- 🔒 **Secure**: Private subnets with proper security groups
- 💾 **Persistent**: EFS storage for workflows and data
- 🌐 **Web Access**: Public load balancer for browser access
- 📊 **Monitoring**: CloudWatch logs and metrics

## Architecture

- **ECS Fargate**: Serverless container hosting
- **Application Load Balancer**: Public web access
- **EFS**: Persistent storage for n8n data
- **VPC**: Isolated network with public/private subnets
- **CloudWatch**: Centralized logging

## Prerequisites

- AWS CLI configured with appropriate permissions
- AWS CDK CLI installed (`npm install -g aws-cdk`)
- Python 3.8+

## Quick Start

### 1. Deploy Infrastructure

```bash
./scripts/deploy.sh
```

This will:
- Set up Python virtual environment
- Install CDK dependencies
- Bootstrap CDK (if needed)
- Deploy the complete infrastructure

### 2. Start N8n

```bash
./scripts/start.sh
```

This will:
- Scale the ECS service to 1 task
- Wait for the service to become healthy
- Display the URL to access n8n

### 3. Access N8n

Open the URL displayed after starting the service. You can now:
- Create workflows
- Set up automations
- Configure integrations

### 4. Stop N8n (Save Costs)

```bash
./scripts/stop.sh
```

This scales the service to 0 tasks, stopping compute charges while preserving your data.

## Management Commands

| Command | Description |
|---------|-------------|
| `./scripts/deploy.sh` | Deploy infrastructure |
| `./scripts/start.sh` | Start n8n service |
| `./scripts/stop.sh` | Stop n8n service |
| `./scripts/status.sh` | Check service status |
| `./scripts/logs.sh` | View real-time logs |
| `./scripts/destroy.sh` | Remove all infrastructure |

## AWS Console Management

You can also manage the service from the AWS Console:

1. **ECS Console**: Navigate to the N8n cluster and service
2. **Update Service**: Change desired count (0=stopped, 1=running)
3. **CloudWatch**: View logs and metrics
4. **Load Balancer**: Monitor health checks

## Configuration

Customize n8n settings in `config/n8n.env`:

- Database configuration (PostgreSQL/MySQL)
- Basic authentication
- Webhook URLs
- Encryption settings
- Logging levels

## Data Persistence

Your n8n data is stored in Amazon EFS and persists across:
- Container restarts
- Service stops/starts
- Task replacements

Data is only lost when you run `./scripts/destroy.sh`.

## Costs

When running (1 Fargate task):
- Fargate: ~$35/month (1 vCPU, 2GB RAM)
- EFS: ~$3/month (10GB storage)
- Load Balancer: ~$16/month
- Data Transfer: Variable

When stopped (0 tasks):
- Only EFS storage costs (~$3/month)

## Security

- N8n runs in private subnets (no direct internet access)
- Load balancer provides controlled public access
- Security groups restrict traffic to necessary ports
- EFS encryption in transit enabled

## Troubleshooting

### Service won't start
```bash
./scripts/logs.sh
```

### Check service status
```bash
./scripts/status.sh
```

### Reset deployment
```bash
./scripts/destroy.sh
./scripts/deploy.sh
```

## Customization

The CDK stack in `cdk/stacks/n8n_stack.py` can be modified for:
- Different instance sizes
- Additional security features
- Database integration (RDS)
- Custom domains with SSL
- VPC peering or VPN connections