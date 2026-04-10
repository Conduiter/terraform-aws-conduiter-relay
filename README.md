# terraform-aws-conduiter-relay
Terraform module to deploy a Conduiter relay (ECS Fargate + ALB) into your AWS account. Accepts inbound encrypted WebSocket  connections and pipes data between sender and receiver daemons. Never decrypts file content.
