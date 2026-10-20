variable "project_name" {
  type        = string
  description = "Proje ön eki"
  default     = "novashop-tf"
}

variable "vpc_id" {
  type        = string
  description = "Security group'ların ekleneceği VPC kimliği"
}

variable "my_ip" {
  type        = string
  description = "SSH erişimi için kullanıcı genel IP adresi (örn: 85.105.42.18/32 veya 0.0.0.0/0)"
  default     = "0.0.0.0/0"
}
