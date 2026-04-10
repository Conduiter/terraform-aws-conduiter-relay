variable "org_token" {
  description = "Organization token for authenticating the relay with the Conduiter API"
  type        = string
  sensitive   = true
}

variable "relay_name" {
  description = "Unique name for this relay instance (used in resource naming and identification)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where relay resources will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ALB and ECS tasks (should span multiple AZs)"
  type        = list(string)
}

variable "allowed_cidrs" {
  description = "List of CIDR blocks allowed to connect to the relay ALB on port 443"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "relay_min_instances" {
  description = "Minimum number of relay task instances for auto-scaling"
  type        = number
  default     = 1
}

variable "relay_max_instances" {
  description = "Maximum number of relay task instances for auto-scaling"
  type        = number
  default     = 10
}

variable "relay_max_daemons_per_instance" {
  description = "Maximum number of daemon connections per relay instance"
  type        = number
  default     = 500
}

variable "task_cpu" {
  description = "CPU units for the relay Fargate task (1 vCPU = 1024)"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Memory in MiB for the relay Fargate task"
  type        = number
  default     = 2048
}

variable "image_tag" {
  description = "Docker image tag for the relay container"
  type        = string
  default     = "latest"
}

variable "api_endpoint" {
  description = "URL of the Conduiter API that the relay will connect to"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS on the ALB"
  type        = string
}
