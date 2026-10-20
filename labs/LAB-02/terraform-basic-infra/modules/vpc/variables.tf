variable "project_name" {
  type        = string
  description = "Proje ön eki (Kaynak adlandırmaları için)"
  default     = "novashop-tf"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC ana IP bloğu (CIDR)"
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidr" {
  type        = string
  description = "EC2 web sunucusunun bulunacağı genel subnet CIDR bloğu"
  default     = "10.1.1.0/24"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "RDS için en az 2 farklı AZ içeren özel subnet CIDR blokları"
  default     = ["10.1.10.0/24", "10.1.11.0/24"]
}
