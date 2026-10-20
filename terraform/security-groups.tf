# 1. EC2 Web Katmanı Güvenlik Grubu
resource "aws_security_group" "web_sg" {
  name        = "novashop-web-sg"
  description = "Allow HTTP, HTTPS, and SSH access to EC2 Web Server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP Ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS Ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "novashop-web-sg"
  }
}

# 2. RDS MySQL Güvenlik Grubu (Yalnızca EC2 Web SG'den gelen 3306 trafiğine izin verir)
resource "aws_security_group" "rds_sg" {
  name        = "novashop-rds-sg"
  description = "Allow MySQL access strictly from EC2 Web Security Group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from EC2 Web SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "novashop-rds-sg"
  }
}
