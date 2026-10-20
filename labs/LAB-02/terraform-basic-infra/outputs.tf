output "vpc_id" {
  description = "Terraform ile oluşturulan VPC ID"
  value       = module.vpc.vpc_id
}

output "ec2_public_ip" {
  description = "EC2 web sunucusunun genel IP adresi"
  value       = module.ec2.public_ip
}

output "ec2_public_dns" {
  description = "EC2 web sunucusunun genel DNS adresi"
  value       = module.ec2.public_dns
}

output "health_check_url" {
  description = "Nginx sağlık kontrolü (Healthcheck) uç noktası"
  value       = "http://${module.ec2.public_ip}/healthz"
}

output "storefront_url" {
  description = "NovaShop test karşılama web sayfası adresi"
  value       = "http://${module.ec2.public_ip}/"
}

output "rds_endpoint" {
  description = "RDS MySQL bağlantı uç noktası (host:port)"
  value       = module.rds.db_endpoint
}

output "ssh_login_command" {
  description = "EC2 sunucusuna SSH ile bağlanma komut örneği"
  value       = "ssh -i ~/.ssh/${var.key_name != "" ? var.key_name : "novashop-key"}.pem ubuntu@${module.ec2.public_ip}"
}
