# Conduiter Relay - AWS Terraform Module

The Conduiter Relay accepts inbound WebSocket connections from sender daemons, validates session tokens, and pipes encrypted data between daemons. The relay never decrypts file content -- it acts purely as a secure transport layer between authenticated endpoints.

## Usage

```hcl
module "relay" {
  source  = "Conduiter/conduiter-relay/aws"
  version = "~> 1.0"

  org_token       = var.org_token
  relay_name      = "production"
  vpc_id          = var.vpc_id
  subnet_ids      = var.subnet_ids
  certificate_arn = var.certificate_arn
  api_endpoint    = "https://api.conduiter.com"
}
```

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.5 |
| AWS provider | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| org_token | Organization token for authenticating the relay with the Conduiter API | `string` | n/a | yes |
| relay_name | Unique name for this relay instance (used in resource naming and identification) | `string` | n/a | yes |
| vpc_id | ID of the VPC where relay resources will be deployed | `string` | n/a | yes |
| subnet_ids | List of subnet IDs for the ALB and ECS tasks (should span multiple AZs) | `list(string)` | n/a | yes |
| allowed_cidrs | List of CIDR blocks allowed to connect to the relay ALB on port 443 | `list(string)` | `["0.0.0.0/0"]` | no |
| relay_min_instances | Minimum number of relay task instances for auto-scaling | `number` | `1` | no |
| relay_max_instances | Maximum number of relay task instances for auto-scaling | `number` | `10` | no |
| relay_max_daemons_per_instance | Maximum number of daemon connections per relay instance | `number` | `500` | no |
| task_cpu | CPU units for the relay Fargate task (1 vCPU = 1024) | `number` | `512` | no |
| task_memory | Memory in MiB for the relay Fargate task | `number` | `2048` | no |
| image_tag | Docker image tag for the relay container | `string` | `"latest"` | no |
| api_endpoint | URL of the Conduiter API that the relay will connect to | `string` | n/a | yes |
| certificate_arn | ARN of the ACM certificate for HTTPS on the ALB | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| relay_endpoint | HTTPS endpoint for the relay ALB |
| relay_id | ECS service ARN used as the relay identifier |
| relay_capacity | Current auto-scaling capacity configuration for the relay |
| alb_arn | ARN of the relay Application Load Balancer |
| security_group_id | ID of the relay ALB security group |

See the [full documentation](https://docs.conduiter.com/getting-started/aws-setup) for detailed setup instructions.
