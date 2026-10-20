terraform {
  backend "s3" {
    key     = "lab-02/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
