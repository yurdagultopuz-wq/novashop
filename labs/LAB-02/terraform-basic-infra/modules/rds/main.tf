# 1. RDS DB Subnet Group (Private Subnet'ler Üzerinde)
resource "aws_db_subnet_group" "this" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Private Subnet Group for NovaShop RDS Database"
  subnet_ids  = var.subnet_ids

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Tier        = "database"
    Provisioner = "terraform"
  }
}

# 2. RDS MySQL Veritabanı Örneği (Single-AZ, Dış Dünyaya Kapalı)
resource "aws_db_instance" "this" {
  identifier             = "${var.project_name}-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  storage_type           = "gp3"
  storage_encrypted      = true
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  multi_az               = false
  skip_final_snapshot    = true
  deletion_protection    = false

  tags = {
    Name        = "${var.project_name}-db"
    Tier        = "database"
    Provisioner = "terraform"
  }
}
