# User Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Quick Start](#quick-start)
5. [Managing Your n8n Instance](#managing-your-n8n-instance)
6. [Working with Workflows](#working-with-workflows)
7. [Backup and Restore](#backup-and-restore)
8. [Configuration](#configuration)
9. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
10. [Cost Management](#cost-management)
11. [Advanced Usage](#advanced-usage)
12. [FAQ](#faq)

## Introduction

This guide walks you through deploying and managing n8n workflow automation on AWS. The system is designed to be cost-effective with the ability to "scale to zero" when not in use, while maintaining data persistence.

### What You'll Get

- n8n workflow automation platform running on AWS
- Persistent storage for all your workflows and data
- Web-based access through a load balancer
- Simple CLI commands for management
- Automatic backups and disaster recovery

### When to Use This

This deployment is ideal for:
- Personal automation projects
- Small team workflow automation
- Development and testing
- Learning n8n without local installation
- Cost-conscious cloud deployments

## Prerequisites

### Required Software

1. **AWS CLI**
   ```bash
   # Install AWS CLI
   brew install awscli  # macOS
   # or
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install

   # Configure with your credentials
   aws configure
   ```

2. **AWS CDK CLI**
   ```bash
   npm install -g aws-cdk

   # Verify installation
   cdk --version
   ```

3. **Python 3.8+**
   ```bash
   python3 --version
   ```

4. **Make** (usually pre-installed on macOS/Linux)
   ```bash
   make --version
   ```

### AWS Account Setup

1. **AWS Account**: You need an AWS account with administrative access
2. **AWS Region**: Choose a region (e.g., us-east-1, us-west-2)
3. **AWS Credentials**: Configure via `aws configure` with:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region
   - Default output format (json)

### Estimated Costs

- **Running**: ~$55/month when active
- **Stopped**: ~$3-19/month (depends on what you keep running)
- **Savings**: ~$32/month less than traditional architecture (no NAT Gateway)
- See [Cost Management](#cost-management) for details

## Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd n8n-aws
```

### 2. Install Dependencies

```bash
make install
```

This command will:
- Create Python virtual environments for CDK and CLI
- Install all required Python packages
- Set up the development environment

### 3. Bootstrap CDK (First Time Only)

If this is your first time using CDK in this AWS account/region:

```bash
cd cdk
source .venv/bin/activate
cdk bootstrap
deactivate
cd ..
```

## Quick Start

### Deploy and Start n8n

The fastest way to get n8n running:

```bash
# 1. Deploy the infrastructure (takes 5-10 minutes)
make deploy ENV=dev

# 2. Start n8n
make start ENV=dev

# 3. Open n8n in your browser
make open ENV=dev
```

That's it! You now have n8n running on AWS.

### Initial n8n Setup

When you first access n8n:

1. You'll be prompted to create an owner account
2. Set a strong password
3. Configure your email (optional)
4. Start creating workflows!

### Stop n8n to Save Costs

When you're done for the day:

```bash
make stop ENV=dev
```

This scales the service to zero, stopping compute charges while keeping your data safe.

## Managing Your n8n Instance

### Starting the Service

Start n8n and wait for it to become healthy:

```bash
make start ENV=dev
```

The command will:
1. Scale the ECS service to 1 task
2. Wait for the task to start
3. Verify health checks pass
4. Display the URL to access n8n

**Time**: ~2-3 minutes

### Stopping the Service

Stop n8n to save on compute costs:

```bash
make stop ENV=dev
```

The command will:
1. Scale the ECS service to 0 tasks
2. Wait for tasks to drain
3. Confirm the service is stopped

**Time**: ~1 minute

**Important**: Your data remains safe on EFS. You can restart anytime.

### Checking Service Status

Get current status of your n8n deployment:

```bash
make status ENV=dev
```

Output includes:
- Service running status
- Number of tasks running
- Task health status
- Load balancer URL
- Recent deployments

### Restarting the Service

Force a restart (useful after configuration changes):

```bash
make restart ENV=dev
```

This is equivalent to:
```bash
make stop ENV=dev && make start ENV=dev
```

### Viewing Logs

Stream live logs from n8n:

```bash
make logs ENV=dev
```

View recent logs (last hour):

```bash
make logs-recent ENV=dev
```

**Tip**: Keep logs open in a separate terminal while testing workflows.

### Opening n8n in Browser

Quickly open the n8n URL in your default browser:

```bash
make open ENV=dev
```

## Working with Workflows

### Understanding Workflow Management

This system supports "workflow as code" - your workflows are stored as JSON files in the `workflows/` directory and version controlled with git.

### Creating Workflows

**Option 1: Create in n8n UI** (Recommended for beginners)

1. Access n8n web interface
2. Create your workflow visually
3. Test and activate it
4. Export to version control (see below)

**Option 2: Create from JSON** (Recommended for advanced users)

1. Create a JSON file in `workflows/` directory
2. Deploy using the CLI (see below)

### Exporting Workflows from n8n

Export all workflows from n8n to local files:

```bash
make export-workflows ENV=dev
```

This will:
1. Connect to n8n API
2. Download all workflow definitions
3. Save as JSON files in `workflows/` directory
4. Update workflow metadata in DynamoDB

**When to export**:
- After creating/modifying workflows in UI
- Before making infrastructure changes
- As part of your regular backup routine

### Deploying Workflows to n8n

**Deploy a single workflow**:

```bash
make deploy-workflow WORKFLOW=workflows/my-workflow.json ENV=dev
```

**Deploy all workflows**:

```bash
make deploy-workflows ENV=dev
```

The deployment process:
1. Validates JSON structure
2. Calculates workflow hash (for change detection)
3. Compares with existing version in DynamoDB
4. Updates/creates workflow via n8n API if changed
5. Records deployment in DynamoDB

### Validating Workflows

Check that all workflow JSON files are valid:

```bash
make validate-workflows
```

This checks:
- Valid JSON syntax
- Required workflow fields present
- No common configuration errors

**Best practice**: Run validation before deploying workflows.

### Workflow Version Control

**Git Workflow**:

```bash
# 1. Make changes in n8n UI
# 2. Export workflows
make export-workflows ENV=dev

# 3. Review changes
git diff workflows/

# 4. Commit if satisfied
git add workflows/
git commit -m "Added customer notification workflow"
git push

# 5. Deploy to production (if applicable)
make deploy-workflows ENV=prod
```

### Workflow Examples

**Example: Simple HTTP Request Workflow**

```json
{
  "name": "Fetch Weather",
  "nodes": [
    {
      "parameters": {
        "url": "https://api.weather.gov/points/39.7456,-97.0892",
        "options": {}
      },
      "name": "HTTP Request",
      "type": "n8n-nodes-base.httpRequest",
      "position": [250, 300],
      "typeVersion": 1
    }
  ],
  "connections": {},
  "active": true,
  "settings": {},
  "id": "1"
}
```

## Backup and Restore

### Manual Backups

Create an immediate backup:

```bash
make backup ENV=dev
```

This backs up:
- n8n database (SQLite file or RDS snapshot)
- All workflow definitions
- Configuration files
- Encrypted credentials

Backups are stored in S3 with the naming format: `YYYYMMDD-HHMMSS`

### Listing Available Backups

See all available backups:

```bash
make list-backups ENV=dev
```

Output shows:
- Backup ID (timestamp)
- Size
- Creation date
- Contents

### Restoring from Backup

Restore a specific backup:

```bash
make restore BACKUP_ID=20231101-120000 ENV=dev
```

**Warning**: This will overwrite current data. The process:
1. Stops the n8n service
2. Downloads backup from S3
3. Replaces current data on EFS
4. Restarts the service

**Time**: ~5-10 minutes

### Backup Best Practices

1. **Regular Schedule**: Back up before major changes
2. **Test Restores**: Periodically test restore process in dev
3. **Off-site Copy**: Consider downloading critical backups locally
4. **Document Changes**: Note what changed since last backup

### Automated Backups (Future)

Set up automated daily backups with EventBridge:

```bash
# Future implementation
make enable-auto-backup ENV=prod SCHEDULE="cron(0 2 * * ? *)"
```

## Configuration

### Environment-Specific Configuration

Configuration files are stored in `config/` directory:

```
config/
├── dev.json      # Development environment
├── staging.json  # Staging environment (optional)
└── prod.json     # Production environment
```

### Configuration File Structure

**Example `config/dev.json`**:

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
  },
  "monitoring": {
    "log_retention_days": 7
  }
}
```

### Customizing n8n Settings

n8n is configured via environment variables in the ECS task definition. Common settings:

**Basic Authentication**:
```python
# In CDK stack
container.add_environment("N8N_BASIC_AUTH_ACTIVE", "true")
container.add_environment("N8N_BASIC_AUTH_USER", "admin")
# Password should be in Secrets Manager
container.add_secret("N8N_BASIC_AUTH_PASSWORD",
    ecs.Secret.from_secrets_manager(secret))
```

**Webhook URL**:
```python
container.add_environment("WEBHOOK_URL",
    f"https://{load_balancer.load_balancer_dns_name}")
```

**Database Configuration** (if using external database):
```python
container.add_environment("DB_TYPE", "postgresdb")
container.add_environment("DB_POSTGRESDB_HOST", rds_instance.db_instance_endpoint_address)
container.add_secret("DB_POSTGRESDB_PASSWORD",
    ecs.Secret.from_secrets_manager(db_secret))
```

### Applying Configuration Changes

After modifying configuration:

```bash
# 1. Update the infrastructure
make deploy ENV=dev

# 2. Restart the service to pick up changes
make restart ENV=dev
```

## Monitoring and Troubleshooting

### Checking Service Health

**Quick Status Check**:
```bash
make status ENV=dev
```

**Detailed CloudWatch Metrics**:
```bash
# Via AWS Console
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=n8n-dev-service \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### Common Issues and Solutions

#### Issue: Service Won't Start

**Symptoms**: `make start` times out or tasks keep failing

**Diagnosis**:
```bash
make logs ENV=dev
```

**Common Causes**:
1. **Insufficient Memory/CPU**: Check logs for OOM errors
   - Solution: Increase resources in `config/dev.json`

2. **EFS Mount Failure**: Check for permission errors
   - Solution: Verify EFS security group allows NFS from ECS

3. **Image Pull Error**: Can't pull n8n Docker image
   - Solution: Check internet connectivity via NAT Gateway

#### Issue: Can't Access n8n URL

**Symptoms**: Load balancer URL returns 503 or times out

**Diagnosis**:
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

**Common Causes**:
1. **Unhealthy Targets**: Tasks failing health checks
   - Solution: Check logs, verify port 5678 responding

2. **Security Group**: Load balancer can't reach tasks
   - Solution: Verify SG allows ALB → ECS on port 5678

3. **Tasks Not Running**: Service scaled to 0
   - Solution: Run `make start ENV=dev`

#### Issue: High Costs

**Symptoms**: Unexpected AWS bill

**Diagnosis**:
```bash
# Check running tasks
aws ecs describe-services \
  --cluster n8n-dev-cluster \
  --services n8n-dev-service

# Check NAT Gateway usage
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available"
```

**Common Causes**:
1. **Forgot to Stop**: Service left running
   - Solution: `make stop ENV=dev`

2. **NAT Gateway Costs**: Data processing charges
   - Solution: Minimize outbound traffic or use VPC endpoints

3. **Data Transfer**: High egress costs
   - Solution: Review workflow external API calls

#### Issue: Workflows Not Executing

**Symptoms**: Workflows appear inactive or fail silently

**Diagnosis**:
```bash
# Check n8n logs
make logs ENV=dev

# Check if workflow is active
curl -u user:pass http://<n8n-url>/api/v1/workflows/<id>
```

**Common Causes**:
1. **Workflow Not Activated**: Forgot to activate after deploy
   - Solution: Activate in n8n UI or via API

2. **Credential Issues**: Missing or invalid credentials
   - Solution: Re-enter credentials in n8n UI

3. **Trigger Misconfiguration**: Webhook or schedule not set up
   - Solution: Review trigger node settings

#### Issue: Data Loss

**Symptoms**: Workflows or data disappeared

**Diagnosis**:
```bash
# Check EFS status
aws efs describe-file-systems

# Check if backup exists
make list-backups ENV=dev
```

**Solutions**:
1. **Restore from Backup**:
   ```bash
   make restore BACKUP_ID=<latest-backup> ENV=dev
   ```

2. **Check Git History**:
   ```bash
   git log workflows/
   git checkout HEAD~1 workflows/
   make deploy-workflows ENV=dev
   ```

### Debugging Workflow Execution

**Enable Verbose Logging**:
```python
# In CDK stack
container.add_environment("N8N_LOG_LEVEL", "debug")
```

**Check Execution Data**:
1. Open n8n UI
2. Go to "Executions" tab
3. View detailed execution logs
4. Check input/output for each node

## Cost Management

### Understanding Your Costs

**When Running (1 task)**:
- ECS Fargate: ~$35/month (1 vCPU, 2GB RAM)
- EFS: ~$0.30/GB-month (~10GB = $3)
- Application Load Balancer: ~$16/month
- Data Transfer: $0.09/GB (outbound)
- CloudWatch Logs: ~$1/month
- **Total: ~$55/month**

**When Stopped (0 tasks)**:
- EFS: ~$3/month (storage only)
- ALB: ~$16/month (if kept running)
- **Total: ~$19/month or ~$3/month if ALB destroyed**

**Architecture Cost Optimization**:
- No NAT Gateway needed (simplified public subnet architecture)
- Saves ~$32/month compared to traditional private subnet design
- ECS tasks run in public subnets with security group protection

### Cost Optimization Strategies

#### 1. Scale to Zero Daily

For personal/development use:

```bash
# End of work day
make stop ENV=dev

# Start of next day
make start ENV=dev
```

**Savings**: ~$35/month in Fargate costs

#### 2. Destroy Non-Essential Infrastructure

When not using n8n for weeks/months:

```bash
# Keep only EFS and backups
cdk destroy LoadBalancerStack ComputeStack --force

# Redeploy when needed
make deploy ENV=dev
```

**Savings**: ~$16/month (ALB only, Fargate already stopped at $0)

#### 3. Use Lifecycle Policies

Move infrequent EFS files to Infrequent Access:

```python
# In CDK stack
file_system.add_lifecycle_policy(
    efs.LifecyclePolicy.AFTER_30_DAYS
)
```

**Savings**: ~90% on files not accessed in 30 days

#### 4. Optimize Data Transfer

- Minimize external API calls in workflows
- Use VPC endpoints for AWS services
- Compress data when possible

#### 5. Right-Size Resources

Monitor actual usage:

```bash
# Check CPU/memory metrics
aws cloudwatch get-metric-statistics ...
```

If usage is low, reduce resources in config:

```json
{
  "resources": {
    "memory": "1024",  // Reduced from 2048
    "cpu": "512"       // Reduced from 1024
  }
}
```

**Savings**: ~50% on Fargate costs

### Setting Up Cost Alerts

Create a billing alarm:

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name n8n-cost-alert \
  --alarm-description "Alert when monthly costs exceed $100" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 100 \
  --comparison-operator GreaterThanThreshold
```

## Advanced Usage

### Using Multiple Environments

Deploy separate dev and prod environments:

```bash
# Development
make deploy ENV=dev
make start ENV=dev

# Production
make deploy ENV=prod
make start ENV=prod
```

Each environment has:
- Separate AWS resources
- Separate configuration
- Separate workflows (or shared via git)

### Integrating with External Database

Replace SQLite with RDS PostgreSQL:

1. **Add RDS Stack** to CDK:
   ```python
   # cdk/stacks/database_stack.py
   rds_instance = rds.DatabaseInstance(...)
   ```

2. **Update n8n Configuration**:
   ```python
   container.add_environment("DB_TYPE", "postgresdb")
   container.add_environment("DB_POSTGRESDB_HOST", db_host)
   ```

3. **Deploy**:
   ```bash
   make deploy ENV=prod
   ```

### Setting Up Custom Domain

Add a custom domain with SSL:

1. **Request ACM Certificate**:
   ```bash
   aws acm request-certificate \
     --domain-name n8n.yourdomain.com
   ```

2. **Update Load Balancer Stack**:
   ```python
   listener = alb.add_listener("HttpsListener",
       port=443,
       certificates=[cert],
       default_target_groups=[target_group]
   )
   ```

3. **Add Route53 Record**:
   ```python
   route53.ARecord(self, "AliasRecord",
       zone=hosted_zone,
       target=route53.RecordTarget.from_alias(
           targets.LoadBalancerTarget(alb)
       )
   )
   ```

### Enabling Webhooks

Configure n8n for webhook access:

```python
# In CDK stack
container.add_environment("WEBHOOK_URL",
    f"https://n8n.yourdomain.com/")
container.add_environment("N8N_HOST", "n8n.yourdomain.com")
container.add_environment("N8N_PROTOCOL", "https")
```

Test webhook:
```bash
curl -X POST https://n8n.yourdomain.com/webhook-test/your-webhook-id \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

### Running Workflows via API

Trigger workflows programmatically:

```bash
# Get workflow ID
curl -u user:pass https://n8n.yourdomain.com/api/v1/workflows

# Execute workflow
curl -X POST https://n8n.yourdomain.com/api/v1/workflows/1/execute \
  -u user:pass \
  -H "Content-Type: application/json" \
  -d '{"data": "input"}'
```

### Monitoring with CloudWatch Dashboards

Create a custom dashboard:

```python
# In CDK stack
dashboard = cloudwatch.Dashboard(self, "N8nDashboard",
    dashboard_name="n8n-monitoring"
)

dashboard.add_widgets(
    cloudwatch.GraphWidget(
        title="CPU Utilization",
        left=[cpu_metric]
    ),
    cloudwatch.GraphWidget(
        title="Memory Utilization",
        left=[memory_metric]
    )
)
```

## FAQ

### General Questions

**Q: What is n8n?**
A: n8n is an open-source workflow automation tool, similar to Zapier or Make.com, that you can self-host.

**Q: Why deploy on AWS instead of using n8n cloud?**
A: Self-hosting gives you full control, no per-workflow limits, and can be more cost-effective for heavy usage.

**Q: Can I use this for production workloads?**
A: Yes, but consider these enhancements:
- External database (RDS instead of SQLite)
- Horizontal scaling (multiple tasks)
- Monitoring and alerting
- Automated backups
- Custom domain with SSL

### Technical Questions

**Q: How do I update the n8n version?**
A: Update the Docker image version in the CDK stack:
```python
image=ecs.ContainerImage.from_registry("n8nio/n8n:1.x.x")
```
Then redeploy: `make deploy ENV=dev`

**Q: Can I run multiple n8n instances?**
A: Yes, increase max tasks in the ECS service. Note: You'll need an external database (not SQLite) for proper operation.

**Q: How do I add custom nodes?**
A: Mount a volume with custom nodes or build a custom Docker image with nodes pre-installed.

**Q: What happens to data when I stop the service?**
A: All data remains on EFS and is available when you restart.

**Q: Can I access n8n from my local machine only?**
A: Yes, modify the ALB security group to allow only your IP:
```python
alb_sg.add_ingress_rule(
    ec2.Peer.ipv4("YOUR.IP.ADDRESS/32"),
    ec2.Port.tcp(80)
)
```

**Q: How do I migrate from local n8n to this deployment?**
A:
1. Export workflows from local n8n (Settings → Workflows → Export)
2. Deploy this infrastructure
3. Import workflows in the new n8n instance
4. Reconfigure credentials

### Troubleshooting Questions

**Q: Why is my deployment taking so long?**
A: Initial deployment can take 10-15 minutes as AWS provisions resources. Subsequent deployments are faster.

**Q: Why can't I access the n8n URL?**
A: Check that:
1. Service is running (`make status`)
2. Security groups allow your IP
3. Tasks are healthy in the target group

**Q: How do I reset my n8n password?**
A: If using basic auth, update the secret in Secrets Manager. For n8n user accounts, you may need to manually update the database.

**Q: Can I use this in a region without public subnets?**
A: No, the ALB requires public subnets. But you can use a private ALB with VPN/Direct Connect access.

### Cost Questions

**Q: Why am I being charged when the service is stopped?**
A: You're still paying for:
- EFS storage (~$3/month)
- Load Balancer (~$16/month)

To eliminate these, destroy the stacks.

**Q: How can I reduce costs further?**
A:
- Destroy load balancer when not in use
- Use EFS Infrequent Access
- Reduce CloudWatch log retention
- Stop service when not in use

**Q: Is this cheaper than n8n cloud?**
A: Depends on usage:
- Light usage: n8n cloud may be cheaper
- Heavy usage: Self-hosting is more cost-effective
- Development/testing: This approach with scale-to-zero is very cost-effective

## Getting Help

### Documentation

- [n8n Documentation](https://docs.n8n.io/)
- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [Project Architecture](./architecture.md)

### Common Commands Reference

```bash
# Infrastructure
make deploy ENV=dev          # Deploy infrastructure
make destroy ENV=dev         # Remove infrastructure
make diff ENV=dev            # Preview changes

# Instance Management
make start ENV=dev           # Start n8n
make stop ENV=dev            # Stop n8n
make restart ENV=dev         # Restart n8n
make status ENV=dev          # Check status
make logs ENV=dev            # View logs
make open ENV=dev            # Open in browser

# Workflow Management
make deploy-workflow WORKFLOW=file.json ENV=dev  # Deploy one workflow
make deploy-workflows ENV=dev                     # Deploy all workflows
make export-workflows ENV=dev                     # Export from n8n
make validate-workflows                           # Validate JSON

# Backup & Restore
make backup ENV=dev                    # Create backup
make list-backups ENV=dev              # List backups
make restore BACKUP_ID=xxx ENV=dev     # Restore backup

# Development
make install                 # Install dependencies
make build                   # Build/validate
make test                    # Run tests
make lint                    # Lint code
make clean                   # Clean artifacts
```

### Next Steps

Now that you've read the user guide:

1. Complete the [Quick Start](#quick-start)
2. Create your first workflow
3. Set up automated backups
4. Configure cost alerts
5. Read the [Architecture Documentation](./architecture.md) for deeper understanding

Happy automating!
