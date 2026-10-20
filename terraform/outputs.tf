output "ec2_public_ip" {
  description = "EC2 web sunucusunun genel IP adresi"
  value       = aws_instance.web.public_ip
}

output "rds_endpoint" {
  description = "RDS MySQL veritabanı uç noktası (endpoint)"
  value       = aws_db_instance.catalog.endpoint
}

output "rds_secret_arn" {
  description = "AWS Secrets Manager tarafından yönetilen parola Secret ARN'i"
  value       = aws_db_instance.catalog.master_user_secret[0].secret_arn
}

output "vpc_id" {
  description = "Oluşturulan NovaShop VPC kimliği"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "Application Load Balancer (ALB) genel DNS adresi"
  value       = aws_lb.main.dns_name
}

output "ecs_cluster_name" {
  description = "Amazon ECS küme adı"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Amazon ECS UI servis adı"
  value       = aws_ecs_service.ui.name
}
