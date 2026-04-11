output "relay_name" {
  description = "Logical name of this relay (use this to wire daemons to the relay)"
  value       = var.relay_name
}

output "relay_endpoint" {
  description = "WSS endpoint for the relay ALB"
  value       = "wss://${aws_lb.relay.dns_name}"
}

output "relay_id" {
  description = "ECS service ARN used as the relay identifier"
  value       = aws_ecs_service.relay.id
}

output "relay_capacity" {
  description = "Current auto-scaling capacity configuration for the relay"
  value = {
    min     = var.relay_min_instances
    max     = var.relay_max_instances
    current = aws_ecs_service.relay.desired_count
  }
}

output "alb_arn" {
  description = "ARN of the relay Application Load Balancer"
  value       = aws_lb.relay.arn
}

output "security_group_id" {
  description = "ID of the relay ALB security group"
  value       = aws_security_group.relay_alb.id
}
