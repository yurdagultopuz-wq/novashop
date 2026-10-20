data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Web Sunucusu
resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e
              apt-get update -y
              apt-get install -y nginx curl ca-certificates gnupg
              
              # Nginx Sağlık ve Statik Karşılama Sayfası
              cat << 'CONF' > /etc/nginx/conf.d/novashop.conf
              server {
                  listen 80 default_server;
                  listen [::]:80 default_server;
                  server_name _;

                  location = /healthz {
                      access_log off;
                      default_type application/json;
                      return 200 '{"status":"UP","layer":"web","provisioner":"terraform"}\n';
                  }

                  location / {
                      default_type text/html;
                      return 200 '<!DOCTYPE html><html><head><title>NovaShop DevOps Store</title></head><body><h1>NovaShop DevOps Store</h1><p>Altyapı Terraform ile otomatik kuruldu.</p></body></html>\n';
                  }
              }
              CONF
              rm -f /etc/nginx/sites-enabled/default
              nginx -t && systemctl restart nginx
              EOF

  tags = {
    Name = "novashop-ec2-web"
  }
}
