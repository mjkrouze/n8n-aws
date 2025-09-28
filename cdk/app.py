#!/usr/bin/env python3
import aws_cdk as cdk
from stacks.n8n_stack import N8nStack

app = cdk.App()

N8nStack(app, "N8nStack",
    env=cdk.Environment(
        account=app.node.try_get_context("account"),
        region=app.node.try_get_context("region") or "us-east-1"
    )
)

app.synth()