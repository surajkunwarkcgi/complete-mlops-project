module "vpc" {
  source = "./vpc"
  environment_name = var.environment_name
  vpc_cidr = var.vpc_cidr
  tags = var.tags
  subnet_newbits = var.subnet_newbits
}