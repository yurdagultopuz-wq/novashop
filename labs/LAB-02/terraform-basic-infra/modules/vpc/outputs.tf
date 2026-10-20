output "vpc_id" {
  description = "Oluşturulan VPC kimliği"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet kimliği (EC2 için)"
  value       = aws_subnet.public.id
}

output "private_subnet_ids" {
  description = "Private subnet kimlikleri listesi (RDS Subnet Group için)"
  value       = aws_subnet.private[*].id
}
