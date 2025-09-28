from aws_cdk import (
    Stack,
    aws_ec2 as ec2,
    aws_ecs as ecs,
    aws_elasticloadbalancingv2 as elbv2,
    aws_efs as efs,
    aws_logs as logs,
    aws_iam as iam,
    CfnOutput,
    Duration,
    RemovalPolicy
)
from constructs import Construct


class N8nStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # VPC
        self.vpc = ec2.Vpc(
            self, "N8nVPC",
            max_azs=2,
            nat_gateways=1,
            ip_addresses=ec2.IpAddresses.cidr("10.0.0.0/16"),
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="Public",
                    subnet_type=ec2.SubnetType.PUBLIC,
                    cidr_mask=24
                ),
                ec2.SubnetConfiguration(
                    name="Private",
                    subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS,
                    cidr_mask=24
                )
            ]
        )

        # Security Groups
        self.alb_security_group = ec2.SecurityGroup(
            self, "ALBSecurityGroup",
            vpc=self.vpc,
            description="Security group for N8n ALB",
            allow_all_outbound=True
        )

        self.alb_security_group.add_ingress_rule(
            ec2.Peer.any_ipv4(),
            ec2.Port.tcp(80),
            "Allow HTTP traffic"
        )

        self.alb_security_group.add_ingress_rule(
            ec2.Peer.any_ipv4(),
            ec2.Port.tcp(443),
            "Allow HTTPS traffic"
        )

        self.ecs_security_group = ec2.SecurityGroup(
            self, "ECSSecurityGroup",
            vpc=self.vpc,
            description="Security group for N8n ECS tasks",
            allow_all_outbound=True
        )

        self.ecs_security_group.add_ingress_rule(
            self.alb_security_group,
            ec2.Port.tcp(5678),
            "Allow traffic from ALB to N8n"
        )

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

        # Task Role
        self.task_role = iam.Role(
            self, "N8nTaskRole",
            assumed_by=iam.ServicePrincipal("ecs-tasks.amazonaws.com")
        )

        # CloudWatch Log Group
        self.log_group = logs.LogGroup(
            self, "N8nLogGroup",
            log_group_name="/ecs/n8n",
            removal_policy=RemovalPolicy.DESTROY,
            retention=logs.RetentionDays.ONE_WEEK
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

        # Application Load Balancer
        self.alb = elbv2.ApplicationLoadBalancer(
            self, "N8nALB",
            vpc=self.vpc,
            internet_facing=True,
            security_group=self.alb_security_group
        )

        # Target Group
        self.target_group = elbv2.ApplicationTargetGroup(
            self, "N8nTargetGroup",
            vpc=self.vpc,
            port=5678,
            protocol=elbv2.ApplicationProtocol.HTTP,
            target_type=elbv2.TargetType.IP,
            health_check=elbv2.HealthCheck(
                enabled=True,
                healthy_http_codes="200",
                interval=Duration.seconds(30),
                path="/",
                protocol=elbv2.Protocol.HTTP,
                timeout=Duration.seconds(10),
                unhealthy_threshold_count=3
            )
        )

        # ALB Listener
        self.listener = self.alb.add_listener(
            "N8nListener",
            port=80,
            protocol=elbv2.ApplicationProtocol.HTTP,
            default_target_groups=[self.target_group]
        )

        # ECS Service
        self.service = ecs.FargateService(
            self, "N8nService",
            cluster=self.cluster,
            task_definition=self.task_definition,
            desired_count=0,  # Start with 0, scale up when needed
            security_groups=[self.ecs_security_group],
            vpc_subnets=ec2.SubnetSelection(
                subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS
            ),
            assign_public_ip=False
        )

        # Register service with target group
        self.service.attach_to_application_target_group(self.target_group)

        # Outputs
        CfnOutput(
            self, "LoadBalancerDNS",
            value=self.alb.load_balancer_dns_name,
            description="DNS name of the load balancer"
        )

        CfnOutput(
            self, "N8nURL",
            value=f"http://{self.alb.load_balancer_dns_name}",
            description="URL to access N8n"
        )

        CfnOutput(
            self, "ClusterName",
            value=self.cluster.cluster_name,
            description="ECS Cluster name"
        )

        CfnOutput(
            self, "ServiceName",
            value=self.service.service_name,
            description="ECS Service name"
        )