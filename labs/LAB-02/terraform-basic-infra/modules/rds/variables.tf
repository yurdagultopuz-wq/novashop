variable "project_name" {
  type        = string
  description = "Proje ön eki"
  default     = "novashop-tf"
}

variable "subnet_ids" {
  type        = list(string)
  description = "DB Subnet Group için en az 2 private subnet kimliği"
}

variable "security_group_id" {
  type        = string
  description = "RDS veritabanı güvenlik grubu kimliği"
}

variable "db_instance_class" {
  type        = string
  description = "RDS MySQL sunucu sınıfı (Kararlı çalışma için db.t3.small önerilir, minimum db.t3.micro)"
  default     = "db.t3.small"
}

variable "db_name" {
  type        = string
  description = "Oluşturulacak başlangıç veritabanı adı"
  default     = "catalogdb"
}

variable "db_username" {
  type        = string
  description = "Veritabanı ana yönetici kullanıcı adı"
  default     = "novashop"
}

variable "db_password" {
  type        = string
  description = "Veritabanı ana yönetici parolası"
  sensitive   = true
  default     = "NovaShopDevOps2026!"
}
