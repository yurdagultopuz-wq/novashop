# 1. EC2 Web Sunucusu Güvenlik Grubu (Port 80 ve Port 22)
resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "NovaShop EC2 Web Tier Security Group (HTTP :80, SSH :22)"
  vpc_id      = var.vpc_id

  # HTTP Web Erişimi (Herkese Açık)
  ingress {
    description = "Allow HTTP traffic from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH Yönetim Erişimi
  ingress {
    description = "Allow SSH management traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Dışa Doğru Tüm Trafik (Paket güncellemeleri ve RDS erişimi için)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-web-sg"
    Tier        = "web"
    Provisioner = "terraform"
  }
}

# 2. RDS Veritabanı Güvenlik Grubu (Yalnızca EC2 Web SG'den Port 3306)
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "NovaShop RDS Database Security Group (MySQL :3306 only from Web SG)"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow MySQL traffic strictly from EC2 Web SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "Allow outbound response traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-rds-sg"
    Tier        = "database"
    Provisioner = "terraform"
  }
}
