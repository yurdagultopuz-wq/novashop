output "db_endpoint" {
  description = "RDS MySQL bağlantı uç noktası (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "RDS MySQL sunucu adresi (hostname)"
  value       = aws_db_instance.this.address
}

output "db_name" {
  description = "Veritabanı adı"
  value       = aws_db_instance.this.db_name
}
