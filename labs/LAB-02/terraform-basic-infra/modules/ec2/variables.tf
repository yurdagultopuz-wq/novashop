variable "project_name" {
  type        = string
  description = "Proje ön eki"
  default     = "novashop-tf"
}

variable "vpc_id" {
  type        = string
  description = "VPC kimliği"
}

variable "subnet_id" {
  type        = string
  description = "EC2 sunucusunun açılacağı genel subnet kimliği"
}

variable "security_group_id" {
  type        = string
  description = "EC2 web güvenlik grubu kimliği"
}

variable "instance_type" {
  type        = string
  description = "EC2 sunucu donanım tipi (Java 21 / Spring Boot için t3.medium önerilir)"
  default     = "t3.medium"
}

variable "key_name" {
  type        = string
  description = "AWS EC2 SSH Key Pair adı (Opsiyonel)"
  default     = ""
}

variable "db_endpoint" {
  type        = string
  description = "RDS veritabanı uç noktası (Test sayfasında ve ortam değişkeninde gösterilmek üzere)"
  default     = "localhost"
}
