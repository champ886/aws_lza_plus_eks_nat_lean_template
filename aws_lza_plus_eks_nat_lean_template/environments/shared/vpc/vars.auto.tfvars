aws_region                    = "ap-southeast-2"
environment                   = "shared"
security_vpc_cidr             = "10.1.0.0/16"
security_public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
security_private_subnet_cidrs = ["10.1.3.0/24", "10.1.4.0/24"]
availability_zones            = ["ap-southeast-2a", "ap-southeast-2b"]