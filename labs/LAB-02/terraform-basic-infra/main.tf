# ==============================================================================
# LAB-02: NovaShop AWS Temel Altyapı (VPC, Security, EC2, RDS) Modüler Mimarisi
# ==============================================================================

# 1. Ağ Modülü (VPC, Subnetler, Internet Gateway, Route Table)
module "vpc" {
  source               = "./modules/vpc"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidr   = var.public_subnet_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
}

# 2. Güvenlik Modülü (EC2 Web SG ve RDS Database SG)
module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  my_ip        = var.my_ip
}

# 3. Veritabanı Modülü (RDS MySQL 8.0, Subnet Group, Private Network)
module "rds" {
  source            = "./modules/rds"
  project_name      = var.project_name
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = module.security.rds_sg_id
  db_instance_class = var.db_instance_class
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
}

# 4. İşlem (Compute) Modülü (Ubuntu 22.04 LTS, Nginx, Cloud-Init, /healthz)
module "ec2" {
  source            = "./modules/ec2"
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.public_subnet_id
  security_group_id = module.security.web_sg_id
  instance_type     = var.ec2_instance_type
  key_name          = var.key_name
  db_endpoint       = module.rds.db_endpoint
}
