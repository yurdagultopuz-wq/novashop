output "web_sg_id" {
  description = "EC2 web sunucusu güvenlik grubu kimliği"
  value       = aws_security_group.web.id
}

output "rds_sg_id" {
  description = "RDS veritabanı güvenlik grubu kimliği"
  value       = aws_security_group.rds.id
}
