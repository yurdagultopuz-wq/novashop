variable "aws_region" {
  type        = string
  description = "Dağıtımın yapılacağı AWS bölgesi"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Proje ön eki (AWS Console kaynaklarıyla çakışmaması için 'novashop-tf' kullanılır)"
  default     = "novashop-tf"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC ana IP bloğu (Console'daki 10.0.0.0/16 ile çakışmaması için 10.1.0.0/16 seçilmiştir)"
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "Genel subnet IP bloğu"
  default     = "10.1.1.0/24"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "RDS için en az 2 farklı AZ barındıran özel subnet IP blokları"
  default     = ["10.1.10.0/24", "10.1.11.0/24"]
}

variable "my_ip" {
  type        = string
  description = "SSH erişimi için izin verilen IP bloğu (Güvenlik için kullanıcı genel IP'si/32 önerilir)"
  default     = "0.0.0.0/0"
}

variable "ec2_instance_type" {
  type        = string
  description = "EC2 sunucu donanım sınıfı (Java 21 / Spring Boot için 4 GB RAM sunan t3.medium önerilir)"
  default     = "t3.medium"
}

variable "key_name" {
  type        = string
  description = "AWS EC2 Key Pair adı (Önceden oluşturulmuşsa giriniz)"
  default     = ""
}

variable "db_instance_class" {
  type        = string
  description = "RDS MySQL instance sınıfı (Kararlı çalışma için db.t3.small önerilir)"
  default     = "db.t3.small"
}

variable "db_name" {
  type        = string
  description = "Başlangıç veritabanı adı"
  default     = "catalogdb"
}

variable "db_username" {
  type        = string
  description = "RDS MySQL yönetici kullanıcı adı"
  default     = "novashop"
}

variable "db_password" {
  type        = string
  description = "RDS MySQL yönetici parolası"
  sensitive   = true
  default     = "NovaShopDevOps2026!"
}
