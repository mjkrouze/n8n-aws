from aws_cdk import (
    Stack,
    aws_ec2 as ec2,
    aws_ecs as ecs,
    aws_efs as efs,
    aws_logs as logs,
    aws_iam as iam,
    aws_events as events,
    aws_events_targets as targets,
    CfnOutput,
    RemovalPolicy
)
from constructs import Construct


class N8nStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # VPC - Simplified with public subnets only (no NAT gateway needed)
        self.vpc = ec2.Vpc(
            self, "N8nVPC",
            max_azs=2,
            nat_gateways=0,  # No NAT gateway needed - saves ~$32/month
            ip_addresses=ec2.IpAddresses.cidr("10.0.0.0/16"),
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="Public",
                    subnet_type=ec2.SubnetType.PUBLIC,
                    cidr_mask=24
                )
            ]
        )

        # Security Groups
        # ECS Security Group - No inbound rules needed (access via Session Manager)
        self.ecs_security_group = ec2.SecurityGroup(
            self, "ECSSecurityGroup",
            vpc=self.vpc,
            description="Security group for N8n ECS tasks",
            allow_all_outbound=True  # Allows pulling images, API calls, etc.
        )

        # Note: No inbound rules needed. Access is via AWS Systems Manager Session Manager
        # which uses the SSM agent and doesn't require open ports

        self.efs_security_group = ec2.SecurityGroup(
            self, "EFSSecurityGroup",
            vpc=self.vpc,
            description="Security group for EFS"
        )

        self.efs_security_group.add_ingress_rule(
            self.ecs_security_group,
            ec2.Port.tcp(2049),
            "Allow NFS traffic from ECS"
        )

        # EFS for data persistence
        self.file_system = efs.FileSystem(
            self, "N8nFileSystem",
            vpc=self.vpc,
            security_group=self.efs_security_group,
            removal_policy=RemovalPolicy.DESTROY,
            performance_mode=efs.PerformanceMode.GENERAL_PURPOSE,
            throughput_mode=efs.ThroughputMode.BURSTING
        )

        # ECS Cluster
        self.cluster = ecs.Cluster(
            self, "N8nCluster",
            vpc=self.vpc,
            container_insights=True
        )

        # CloudWatch Log Group
        self.log_group = logs.LogGroup(
            self, "N8nLogGroup",
            log_group_name="/ecs/n8n",
            removal_policy=RemovalPolicy.DESTROY,
            retention=logs.RetentionDays.ONE_WEEK
        )

        # Task Execution Role
        self.execution_role = iam.Role(
            self, "N8nExecutionRole",
            assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com"),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name(
                    "service-role/AmazonECSTaskExecutionRolePolicy"
                )
            ]
        )

        # Task Role - with Session Manager permissions
        self.task_role = iam.Role(
            self, "N8nTaskRole",
            assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com")
        )

        # Add Session Manager permissions for ECS Exec
        self.task_role.add_managed_policy(
            iam.ManagedPolicy.from_aws_managed_policy_name(
                "AmazonSSMManagedInstanceCore"
            )
        )

        # Allow task to write to CloudWatch Logs for Session Manager
        self.task_role.add_to_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "logs:DescribeLogStreams"
                ],
                resources=[f"{self.log_group.log_group_arn}:*"]
            )
        )

        # Task Definition
        self.task_definition = ecs.FargateTaskDefinition(
            self, "N8nTaskDefinition",
            memory_limit_mib=2048,
            cpu=1024,
            execution_role=self.execution_role,
            task_role=self.task_role
        )

        # Add EFS volume to task definition
        self.task_definition.add_volume(
            name="n8n-data",
            efs_volume_configuration=ecs.EfsVolumeConfiguration(
                file_system_id=self.file_system.file_system_id,
                transit_encryption="ENABLED"
            )
        )

        # Container Definition
        self.container = self.task_definition.add_container(
            "N8nContainer",
            image=ecs.ContainerImage.from_registry("n8nio/n8n:latest"),
            logging=ecs.LogDrivers.aws_logs(
                stream_prefix="n8n",
                log_group=self.log_group
            ),
            environment={
                "N8N_HOST": "0.0.0.0",
                "N8N_PORT": "5678",
                "N8N_PROTOCOL": "http",
                "WEBHOOK_URL": "http://localhost:5678/",
                "GENERIC_TIMEZONE": "UTC"
            },
            port_mappings=[
                ecs.PortMapping(
                    container_port=5678,
                    protocol=ecs.Protocol.TCP
                )
            ]
        )

        # Add mount point for EFS
        self.container.add_mount_points(
            ecs.MountPoint(
                source_volume="n8n-data",
                container_path="/home/node/.n8n",
                read_only=False
            )
        )

        # ECS Service - Running in public subnet with Session Manager access
        self.service = ecs.FargateService(
            self, "N8nService",
            cluster=self.cluster,
            task_definition=self.task_definition,
            desired_count=0,  # Start with 0, scale up when needed
            security_groups=[self.ecs_security_group],
            vpc_subnets=ec2.SubnetSelection(
                subnet_type=ec2.SubnetType.PUBLIC
            ),
            assign_public_ip=True,  # Required for public subnet to pull images and access internet
            enable_execute_command=True  # Enable ECS Exec for Session Manager access
        )

        # Optional: EventBridge rule for scheduled startup
        # Uncomment to auto-start service on a schedule (e.g., Monday 8 AM UTC)
        # self.start_rule = events.Rule(
        #     self, "StartN8nRule",
        #     schedule=events.Schedule.cron(
        #         minute="0",
        #         hour="8",
        #         week_day="MON"
        #     ),
        #     description="Start n8n service on schedule"
        # )
        # self.start_rule.add_target(
        #     targets.EcsTask(
        #         cluster=self.cluster,
        #         task_definition=self.task_definition,
        #         subnet_selection=ec2.SubnetSelection(
        #             subnet_type=ec2.SubnetType.PUBLIC
        #         ),
        #         assign_public_ip=True
        #     )
        # )

        # Outputs
        CfnOutput(
            self, "ClusterName",
            value=self.cluster.cluster_name,
            description="ECS Cluster name (use for Session Manager access)",
            export_name=f"{self.stack_name}-ClusterName"
        )

        CfnOutput(
            self, "ServiceName",
            value=self.service.service_name,
            description="ECS Service name (use for Session Manager access)",
            export_name=f"{self.stack_name}-ServiceName"
        )

        CfnOutput(
            self, "AccessInstructions",
            value="Use 'make connect' or AWS Session Manager to access n8n",
            description="How to access n8n (no ALB - Session Manager only)"
        )