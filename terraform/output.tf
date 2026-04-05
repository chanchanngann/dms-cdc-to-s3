###################################
# DMS
###################################

output "dms_vpc_id" {
  value = module.dms_vpc.vpc_id
}

output "dms_vpc_cidr_block" {
  value = module.dms_vpc.vpc_cidr_block
}

###################################
# RDS - source_db
###################################

output "secret_source_db" {
  value = random_string.source_db.id
}

output "source_db_postgres_endpoint_address" {
  value = aws_db_instance.source_db.address
}

output "source_db_postgres_endpoint_port" {
  value = aws_db_instance.source_db.port
}

output "source_db_postgres_db_name" {
  value = aws_db_instance.source_db.db_name
}

output "source_db_postgres_username" {
  value     = aws_db_instance.source_db.username
  sensitive = true
}

output "source_db_postgres_password" {
  value     = aws_db_instance.source_db.password
  sensitive = true
}

###################################
# Bastion
###################################

output "ec2_instance_id" {
  value = aws_instance.ec2.id
}