# 1. RDS DB Subnet Group (Private Subnet'ler)
resource "aws_db_subnet_group" "rds" {
  name        = "novashop-rds-subnet-group"
  description = "Private subnets for NovaShop catalog database"
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name = "novashop-rds-subnet-group"
  }
}

# 2. RDS MySQL Instance (Single-AZ, Secrets Manager Yönetimli Şifre)
resource "aws_db_instance" "catalog" {
  identifier                  = "novashop-catalog-db"
  engine                      = "mysql"
  engine_version              = "8.0"
  instance_class              = var.db_instance_class
  allocated_storage           = 20
  max_allocated_storage       = 50
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true # Parola AWS Secrets Manager tarafından otomatik üretilir ve saklanır
  db_subnet_group_name        = aws_db_subnet_group.rds.name
  vpc_security_group_ids      = [aws_security_group.rds_sg.id]
  publicly_accessible         = false
  multi_az                    = false
  backup_retention_period     = 0
  skip_final_snapshot         = true
  deletion_protection         = false

  tags = {
    Name = "novashop-catalog-db"
  }
}
