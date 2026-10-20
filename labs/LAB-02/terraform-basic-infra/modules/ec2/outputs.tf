output "instance_id" {
  description = "EC2 sunucu örnek kimliği"
  value       = aws_instance.web.id
}

output "public_ip" {
  description = "EC2 sunucusu genel IP adresi"
  value       = aws_instance.web.public_ip
}

output "public_dns" {
  description = "EC2 sunucusu genel DNS adı"
  value       = aws_instance.web.public_dns
}
