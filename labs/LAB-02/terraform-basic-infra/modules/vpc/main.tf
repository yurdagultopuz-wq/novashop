data "aws_availability_zones" "available" {
  state = "available"
}

# 1. Sanal Özel Bulut (VPC)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Provisioner = "terraform"
  }
}

# 2. İnternet Ağ Geçidi (Internet Gateway)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Provisioner = "terraform"
  }
}

# 3. Public Subnet (EC2 Web Katmanı)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-1a"
    Tier        = "public"
    Provisioner = "terraform"
  }
}

# 4. Private Subnet'ler (RDS MySQL Katmanı - 2 AZ Zorunluluğu)
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.project_name}-private-1${count.index == 0 ? "a" : "b"}"
    Tier        = "private"
    Provisioner = "terraform"
  }
}

# 5. Public Route Table ve İnternet Rotası (0.0.0.0/0 -> IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Provisioner = "terraform"
  }
}

# 6. Public Subnet Route Table İlişkilendirmesi
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
