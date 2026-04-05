region = ""

vpc_name = "dms-vpc"

vpc_cidr = "10.0.0.0/16"

vpc_private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

vpc_azs = ["", "", ""]

dms_s3_bucket = ""

instance_size = "t3.micro"

common_tags = {
  Project     = "dms-lab"
  Environment = "dev"
  Owner       = "xxx"
  Terraform   = "true"
}
