# Architecture Documentation

## Overview

This document describes the technical architecture of the n8n AWS deployment system. The project deploys and manages n8n (workflow automation tool) on AWS using ECS Fargate, with supporting infrastructure for data persistence, state management, and backups.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │  Application Load    │
            │      Balancer        │
            └──────────┬───────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
        ▼                             ▼
┌───────────────┐            ┌───────────────┐
│ Public Subnet │            │ Public Subnet │
│    (AZ-1)     │            │    (AZ-2)     │
│               │            │               │
│  ┌─────────┐  │            │  ┌─────────┐  │
│  │   ECS   │◄─┼────────────┼─►│   ECS   │  │
│  │ Fargate │  │            │  │ Fargate │  │
│  │  Task   │  │            │  │  Task   │  │
│  └────┬────┘  │            │  └────┬────┘  │
│       │       │            │       │       │
└───────┼───────┘            └───────┼───────┘
        │         VPC                │
        └────────────┬───────────────┘
                     │
                     ▼
            ┌────────────────┐
            │      EFS       │
            │   File System  │
            └────────────────┘

     ┌─────────────┐      ┌─────────────┐
     │  DynamoDB   │      │     S3      │
     │   Tables    │      │   Backups   │
     └─────────────┘      └─────────────┘

            ┌────────────────┐
            │   CloudWatch   │
            │  Logs/Metrics  │
            └────────────────┘
```

**Note**: This is a simplified architecture optimized for cost. ECS tasks run in public subnets with public IP addresses, eliminating the need for NAT Gateways (~$32/month savings).

## Core Components

### 1. Compute Layer (ECS Fargate)

**Purpose**: Runs the n8n application container in a serverless manner.

**Key Features**:
- **Serverless**: No EC2 instances to manage
- **Scalable**: Can scale to zero when not in use (cost optimization)
- **Multi-AZ**: Deployed across multiple availability zones for reliability
- **Task Definition**: Defines container image, resources (CPU/memory), environment variables

**Configuration**:
```python
# Task sizing
CPU: 1024 (1 vCPU)
Memory: 2048 MB (2 GB)

# Scaling
Min tasks: 0
Max tasks: 1
Desired count: 0 (by default, controlled via CLI)
```

**Why ECS Fargate?**
- No server management overhead
- Pay only for what you use
- Easy to scale to zero for cost savings
- Built-in AWS integration

### 2. Networking Layer (VPC)

**Purpose**: Provides isolated network environment with simplified topology for cost optimization.

**Structure**:
- **VPC**: Dedicated virtual private cloud (10.0.0.0/16)
- **Public Subnets**: Host both load balancer and ECS tasks (2 AZs for high availability)
- **Internet Gateway**: Enables direct internet access for public subnets
- **No NAT Gateway**: Cost savings of ~$32/month by running ECS in public subnets

**Security Groups**:
```
Load Balancer SG:
- Inbound: 80 (HTTP), 443 (HTTPS) from 0.0.0.0/0
- Outbound: All traffic to ECS SG

ECS Service SG:
- Inbound: 5678 (n8n port) from Load Balancer SG only
- Outbound: All traffic (for API calls, webhooks, etc.)

EFS SG:
- Inbound: 2049 (NFS) from ECS SG only
- Outbound: None required
```

**Why Public Subnets?**
- **Cost Optimization**: Eliminates ~$32/month NAT Gateway cost
- **Simplified Architecture**: Fewer components to manage
- **Adequate Security**: Security groups provide isolation, ECS tasks only accept traffic from ALB
- **Low Risk**: Suitable for personal/development use cases
- **Direct Internet Access**: Tasks can pull Docker images and make API calls without NAT

### 3. Storage Layer

#### EFS (Elastic File System)

**Purpose**: Provides persistent storage for n8n data, workflows, and credentials.

**Features**:
- **Persistent**: Data survives container restarts and task replacements
- **Shared**: Multiple tasks can mount the same file system
- **Encrypted**: Encryption in transit enabled
- **Scalable**: Automatically grows and shrinks with usage

**Mount Points**:
```
/home/node/.n8n - n8n data directory
├── config/      - Configuration files
├── database.sqlite - SQLite database (or config for external DB)
├── workflows/   - Workflow definitions
└── credentials/ - Encrypted credentials
```

**Why EFS?**
- Native support for ECS Fargate
- No capacity planning needed
- Multi-AZ availability
- Cost-effective for small to medium data

#### DynamoDB (State Management)

**Purpose**: Tracks deployment state, workflow metadata, and deployment history.

**Tables**:

1. **deployment-state**
   - Partition Key: `resource_id` (e.g., "ecs-service", "cluster")
   - Attributes: `status`, `last_updated`, `metadata`
   - Use case: Track current state of AWS resources

2. **workflow-metadata**
   - Partition Key: `workflow_id`
   - Sort Key: `version`
   - Attributes: `hash`, `deployed_at`, `status`, `name`
   - Use case: Version control and deployment tracking

**Why DynamoDB?**
- Serverless (no infrastructure to manage)
- Fast key-value lookups
- Built-in versioning support
- Cost-effective for low-volume operations

#### S3 (Backups)

**Purpose**: Store n8n database and workflow backups.

**Bucket Structure**:
```
n8n-backups-{account-id}-{region}/
├── database/
│   ├── 20231101-120000.sqlite
│   └── 20231102-120000.sqlite
└── workflows/
    ├── 20231101-120000/
    │   ├── workflow-1.json
    │   └── workflow-2.json
    └── 20231102-120000/
        └── ...
```

**Lifecycle Policy**:
- Transition to Glacier after 30 days
- Delete after 90 days
- Versioning enabled

**Why S3?**
- Highly durable (99.999999999%)
- Cost-effective for archival
- Easy to restore from
- Supports lifecycle policies

### 4. Load Balancer (ALB)

**Purpose**: Provides public access to n8n web interface and handles SSL termination.

**Configuration**:
- **Type**: Application Load Balancer (Layer 7)
- **Scheme**: Internet-facing
- **Listeners**:
  - HTTP (80) - redirect to HTTPS (optional)
  - HTTPS (443) - forward to ECS tasks (when SSL configured)
- **Target Group**: ECS tasks on port 5678
- **Health Check**: HTTP GET on `/` with 30s interval

**Why ALB?**
- HTTP/HTTPS routing
- SSL termination support
- Health checks and automatic failover
- Integration with AWS Certificate Manager

### 5. Monitoring & Logging (CloudWatch)

**Purpose**: Centralized logging and monitoring for troubleshooting and alerting.

**Components**:

1. **Log Groups**:
   - `/ecs/n8n` - Container logs
   - Retention: 7 days (configurable)

2. **Metrics**:
   - CPU utilization
   - Memory utilization
   - Task count
   - Load balancer request count
   - Load balancer response time

3. **Alarms** (future):
   - High CPU usage
   - High memory usage
   - Unhealthy target count
   - High error rate

**Why CloudWatch?**
- Native AWS integration
- Real-time log streaming
- Metric visualization
- Alarm capabilities

## Infrastructure as Code (CDK)

### Stack Architecture

The infrastructure is organized into modular CDK stacks for maintainability:

```
app.py (main entry point)
│
├── NetworkStack
│   ├── VPC
│   ├── Subnets
│   ├── Internet Gateway
│   └── NAT Gateway
│
├── StorageStack
│   ├── EFS File System
│   ├── Mount Targets
│   └── Security Groups
│
├── DatabaseStack (future)
│   └── DynamoDB Tables
│
├── ComputeStack
│   ├── ECS Cluster
│   ├── Task Definition
│   ├── Service
│   └── Security Groups
│
└── LoadBalancerStack
    ├── Application Load Balancer
    ├── Target Group
    ├── Listener
    └── Security Groups
```

**Stack Dependencies**:
```
NetworkStack (base)
    ↓
StorageStack + DatabaseStack (parallel)
    ↓
ComputeStack
    ↓
LoadBalancerStack
```

**Why Modular Stacks?**
- Independent deployment and updates
- Easier to test and debug
- Better separation of concerns
- Reusable components

## CLI Architecture

### Component Structure

```
cli/
├── main.py              # Entry point, argument parsing
├── commands/            # Command implementations
│   ├── start.py        # Start n8n service
│   ├── stop.py         # Stop n8n service
│   ├── status.py       # Check service status
│   ├── deploy.py       # Deploy workflows
│   ├── backup.py       # Backup operations
│   └── restore.py      # Restore operations
└── utils/              # Shared utilities
    ├── aws_client.py   # Boto3 wrapper (ECS, S3, DynamoDB)
    ├── n8n_client.py   # n8n REST API client
    ├── config.py       # Configuration management
    └── logger.py       # Logging setup
```

### Command Flow Example: Start Service

```
User: make start ENV=dev
  ↓
Makefile → scripts/start.sh → cli/main.py start --env dev
  ↓
start.py:
  1. Load config from config/dev.json
  2. Get ECS cluster and service names
  3. Call AWS API to update desired count to 1
  4. Poll service status until healthy
  5. Query load balancer DNS name
  6. Display URL to user
```

### n8n API Integration

**Authentication**:
- API Key stored in AWS Secrets Manager
- Injected into CLI via environment variable

**Key Endpoints Used**:
```
GET  /workflows          - List all workflows
POST /workflows          - Create new workflow
GET  /workflows/:id      - Get workflow details
PUT  /workflows/:id      - Update workflow
POST /workflows/:id/activate - Activate workflow
```

**Workflow Deployment Flow**:
```
1. Read workflow JSON from file
2. Calculate hash (for change detection)
3. Query DynamoDB for existing workflow
4. If hash changed:
   a. Call n8n API to update/create workflow
   b. Update DynamoDB with new version
   c. Activate workflow if specified
5. Log deployment to CloudWatch
```

## Security Architecture

### Defense in Depth

**Layer 1: Network**
- Private subnets for compute
- Security groups with least privilege
- VPC flow logs (optional)

**Layer 2: IAM**
- Task execution role (for AWS service access)
- Task role (for application permissions)
- Separate roles for CLI operations
- No hardcoded credentials

**Layer 3: Encryption**
- EFS encryption in transit (TLS)
- EFS encryption at rest (optional)
- S3 encryption at rest (AES-256)
- Secrets Manager for sensitive data

**Layer 4: Application**
- n8n basic authentication
- HTTPS only (when SSL configured)
- Webhook signature validation

### IAM Roles

**ECS Task Execution Role**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "*"
    }
  ]
}
```

**ECS Task Role** (for n8n application):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": "arn:aws:s3:::n8n-backups-*/*"
    }
  ]
}
```

**CLI Role** (for management operations):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:UpdateService",
        "ecs:DescribeServices",
        "ecs:DescribeTasks",
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:ecs:*:*:service/n8n-*",
        "arn:aws:dynamodb:*:*:table/n8n-*",
        "arn:aws:s3:::n8n-backups-*/*"
      ]
    }
  ]
}
```

## Cost Optimization

### Cost Breakdown

**Running State** (1 Fargate task):
- ECS Fargate: ~$35/month (1 vCPU, 2GB RAM)
- EFS: ~$0.30/GB-month (estimate 10GB = $3)
- ALB: ~$16/month
- Data transfer: Variable ($0.09/GB outbound)
- CloudWatch Logs: ~$1/month
- **Total: ~$55/month**

**Stopped State** (0 tasks):
- EFS: ~$3/month (only storage)
- ALB: ~$16/month (if kept running)
- **Total: ~$19/month or ~$3/month if ALB destroyed**

**Cost Savings from Simplified Architecture**:
- No NAT Gateway: Saves ~$32/month
- No private subnets: Simpler to manage
- Total monthly savings: ~$32/month compared to traditional architecture

### Cost Optimization Strategies

1. **Scale to Zero**: Primary cost savings mechanism
   ```bash
   make stop ENV=dev
   ```

2. **Destroy Non-Essential Resources** (when not in use for extended periods):
   ```bash
   # Only keeps EFS and S3
   cdk destroy LoadBalancerStack ComputeStack
   ```

3. **Use Fargate Spot** (future enhancement):
   - 70% discount over on-demand
   - Suitable for non-production environments

4. **EFS Lifecycle Management**:
   - Move to Infrequent Access after 30 days
   - 90% cost reduction for rarely accessed files

5. **CloudWatch Logs Retention**:
   - Set appropriate retention (7 days instead of forever)
   - Saves on storage costs

6. **Right-Size Resources**:
   - Monitor actual CPU/memory usage
   - Adjust task definition if over-provisioned

## Scalability & Performance

### Current Limitations

- Single task (not horizontally scaled)
- Single region deployment
- SQLite database (not suitable for high concurrency)

### Future Scaling Options

**Horizontal Scaling**:
```python
# Update ECS service
max_tasks = 10
auto_scaling = ecs.ScalableTaskCount(...)
```

**Database Scaling**:
- Replace SQLite with RDS PostgreSQL
- Enable RDS read replicas for read scaling
- Use Aurora Serverless for automatic scaling

**Multi-Region**:
- Deploy stacks in multiple regions
- Use Route53 for DNS failover
- Replicate S3 backups cross-region

**Performance Optimizations**:
- Enable EFS provisioned throughput
- Use CloudFront CDN for static assets
- Implement caching layer (ElastiCache)

## Disaster Recovery

### Backup Strategy

**Automated Backups**:
```bash
# Daily via cron or EventBridge
make backup ENV=prod
```

**What's Backed Up**:
- SQLite database (or RDS snapshot)
- Workflow definitions
- Environment configuration
- Credentials (encrypted)

**Retention**:
- Daily backups: 30 days
- Weekly backups: 90 days
- Monthly backups: 1 year

### Recovery Procedures

**Scenario 1: Corrupted Workflow**
```bash
# Export current workflows
make export-workflows ENV=prod

# Restore specific workflow from git history
git checkout HEAD~1 workflows/workflow-1.json
make deploy-workflow WORKFLOW=workflow-1.json ENV=prod
```

**Scenario 2: Complete Data Loss**
```bash
# Restore from most recent backup
make restore BACKUP_ID=20231101-120000 ENV=prod

# Restart service
make restart ENV=prod
```

**Scenario 3: Region Failure**
- Restore from S3 backup in different region
- Deploy infrastructure in new region
- Update DNS to point to new region

**RTO/RPO**:
- RTO (Recovery Time Objective): < 1 hour
- RPO (Recovery Point Objective): < 24 hours (daily backups)

## Monitoring & Observability

### Key Metrics to Monitor

1. **Service Health**:
   - ECS task count (should match desired count)
   - Task health status
   - Load balancer healthy target count

2. **Performance**:
   - CPU utilization (alert if > 80%)
   - Memory utilization (alert if > 90%)
   - Response time (p50, p95, p99)

3. **Application**:
   - Workflow execution count
   - Workflow failure rate
   - API error rate

4. **Infrastructure**:
   - EFS throughput
   - EFS storage used
   - Data transfer costs

### Logging Strategy

**Structured Logging**:
```json
{
  "timestamp": "2023-11-01T12:00:00Z",
  "level": "INFO",
  "service": "n8n",
  "workflow_id": "abc123",
  "message": "Workflow executed successfully",
  "duration_ms": 1234
}
```

**Log Aggregation**:
- All logs → CloudWatch Logs
- Optional: Stream to S3 for long-term storage
- Optional: Forward to external service (Datadog, Splunk)

### Alerting

**Critical Alerts** (future implementation):
- Service unhealthy for > 5 minutes
- CPU > 90% for > 10 minutes
- Error rate > 5% over 5 minutes
- No successful workflow executions in 1 hour

**Notification Channels**:
- CloudWatch Alarms → SNS → Email/Slack
- PagerDuty for on-call escalation

## Deployment Pipeline (Future)

### CI/CD Architecture

```
Developer → Git Push
  ↓
GitHub Actions / GitLab CI
  ↓
  1. Lint & Test
  2. Build (if needed)
  3. CDK Diff (review changes)
  4. Manual Approval (for prod)
  5. CDK Deploy
  6. Deploy Workflows
  7. Run Integration Tests
  8. Rollback on Failure
```

### Blue/Green Deployment

For zero-downtime updates:
```
1. Deploy new task definition (green)
2. Route 10% of traffic to green
3. Monitor error rates
4. Gradually shift to 100%
5. Decommission old tasks (blue)
```

## Technology Decisions

### Why These Choices?

**AWS CDK over Terraform**:
- Type-safe infrastructure code
- Better AWS integration
- Faster development with constructs
- Native CloudFormation features

**Python over TypeScript**:
- Wider accessibility
- Better for scripting/CLI
- Rich AWS SDK (boto3)
- Team familiarity

**ECS Fargate over Lambda**:
- Long-running workflows
- Consistent environment
- No 15-minute Lambda timeout
- Full container control

**SQLite over RDS** (initial):
- Simpler setup
- Lower cost for low usage
- File-based (easy backup)
- Sufficient for single-user/low-volume

**EFS over EBS**:
- Multi-AZ availability
- Shared access (multiple tasks)
- No capacity planning
- Automatic scaling

## References

- [AWS CDK Best Practices](https://docs.aws.amazon.com/cdk/latest/guide/best-practices.html)
- [ECS Fargate Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [n8n Self-Hosting](https://docs.n8n.io/hosting/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
