variable "aws_region" {
  type        = string
  description = "AWS dağıtım bölgesi"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Dağıtım ortamı etiketi"
  default     = "dev"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC ana CIDR bloğu"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Genel subnet CIDR listesi (2 AZ)"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Özel subnet CIDR listesi (2 AZ)"
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "ec2_instance_type" {
  type        = string
  description = "EC2 sunucu tipi"
  default     = "t3.micro"
}

variable "db_instance_class" {
  type        = string
  description = "RDS MySQL instance sınıfı"
  default     = "db.t3.micro"
}

variable "db_username" {
  type        = string
  description = "RDS MySQL ana kullanıcı adı"
  default     = "novashop"
}

variable "db_name" {
  type        = string
  description = "RDS başlangıç veritabanı adı"
  default     = "catalogdb"
}
