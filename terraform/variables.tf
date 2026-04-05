####################################
# General 
####################################

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "common_tags" {
  type = map(any)
}


###################################
# S3 bucket
###################################

variable "dms_s3_bucket" {
  type        = string
  description = "S3 bucket for dms"
}

###################################
# VPC
###################################
variable "vpc_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "vpc_azs" {
  type = list(any)
}

variable "vpc_private_subnets" {
  type = list(any)
}

###################################
# Bastion host
###################################

variable "instance_size" {
  type = string
}

