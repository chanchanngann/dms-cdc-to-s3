provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}


###################################
# VPC, Subnet
###################################
module "dms_vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  name                 = var.vpc_name
  cidr                 = var.vpc_cidr
  azs                  = var.vpc_azs
  private_subnets      = var.vpc_private_subnets
  tags                 = var.common_tags
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_dms_replication_subnet_group" "dms_subnet_group" {
  replication_subnet_group_description = "dms subnet group"
  replication_subnet_group_id          = "dms-subnet-group"

  subnet_ids = module.dms_vpc.private_subnets

}

###################################
# S3 bucket
###################################
resource "aws_s3_bucket" "dms" {
  bucket = var.dms_s3_bucket

}


###################################
# DMS instance
###################################
resource "aws_dms_replication_instance" "test" {
  allocated_storage           = 20
  apply_immediately           = true
  auto_minor_version_upgrade  = false
  availability_zone           = var.vpc_azs[0]
  publicly_accessible         = false
  replication_instance_class  = "dms.t3.medium"
  replication_instance_id     = "dms-instance"
  replication_subnet_group_id = aws_dms_replication_subnet_group.dms_subnet_group.id

  vpc_security_group_ids = [aws_security_group.dms_sec_group.id]

  depends_on = [
    aws_iam_role_policy_attachment.dms-access-for-endpoint-AmazonDMSRedshiftS3Role,
    # aws_iam_role.dms-access-for-endpoint,
    aws_iam_role_policy_attachment.dms-cloudwatch-logs-role-AmazonDMSCloudWatchLogsRole,
    aws_iam_role_policy_attachment.dms-vpc-role-AmazonDMSVPCManagementRole
  ]
}

resource "aws_security_group" "dms_sec_group" {
  name_prefix = "dms_sg"
  vpc_id      = module.dms_vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###################################
# IAM role (DMS)
###################################
# s3 access
resource "aws_iam_role" "dms-access-for-endpoint" {
  assume_role_policy = data.aws_iam_policy_document.dms_assume_role.json
  name               = "dms-access-for-endpoint"
}

resource "aws_iam_role_policy_attachment" "dms-access-for-endpoint-AmazonDMSRedshiftS3Role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSRedshiftS3Role"
  role       = aws_iam_role.dms-access-for-endpoint.name
}

# cloudwatch access
resource "aws_iam_role" "dms-cloudwatch-logs-role" {
  assume_role_policy = data.aws_iam_policy_document.dms_assume_role.json
  name               = "dms-cloudwatch-logs-role"
}

resource "aws_iam_role_policy_attachment" "dms-cloudwatch-logs-role-AmazonDMSCloudWatchLogsRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
  role       = aws_iam_role.dms-cloudwatch-logs-role.name
}

# vpc access
resource "aws_iam_role" "dms-vpc-role" {
  assume_role_policy = data.aws_iam_policy_document.dms_assume_role.json
  name               = "dms-vpc-role"
}

resource "aws_iam_role_policy_attachment" "dms-vpc-role-AmazonDMSVPCManagementRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
  role       = aws_iam_role.dms-vpc-role.name
}

###################################
# DMS endpoints
###################################
locals {
  db_creds_source = jsondecode(aws_secretsmanager_secret_version.source_db_secret.secret_string)
}

resource "aws_dms_s3_endpoint" "target" {
  endpoint_id             = "s3-target"
  endpoint_type           = "target"
  bucket_name             = var.dms_s3_bucket
  add_column_name         = true
  data_format             = "parquet"
  timestamp_column_name   = "dms_ts"
  date_partition_enabled  = true
  date_partition_sequence = "YYYYMMDD"
  date_partition_timezone = "Asia/Seoul"
  # glue_catalog_generation                     = true

  service_access_role_arn = aws_iam_role.dms-access-for-endpoint.arn

  depends_on = [aws_iam_role.dms-access-for-endpoint]

}

resource "aws_dms_endpoint" "source" {
  endpoint_id   = "source-db"
  endpoint_type = "source"
  engine_name   = "postgres"
  database_name = "demo_db"
  server_name   = aws_db_instance.source_db.address
  username      = local.db_creds_source.username
  password      = local.db_creds_source.password
  port          = 5432
  ssl_mode      = "require"
}

#################################################
# DMS replication task
#################################################
resource "aws_dms_replication_task" "task" {
  replication_task_id      = "test-task"
  migration_type           = "full-load-and-cdc"
  replication_instance_arn = aws_dms_replication_instance.test.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_s3_endpoint.target.endpoint_arn

  table_mappings = jsonencode({
    rules = [
      {
        rule-type = "selection"
        rule-id   = "1"
        rule-name = "1"
        object-locator = {
          schema-name = "public"
          table-name  = "%"
        }
        rule-action = "include"
      }
    ]
  })

  replication_task_settings = jsonencode({
    FullLoadSettings = {
      TargetTablePrepMode = "TRUNCATE_BEFORE_LOAD"
    },
    Logging = {
      EnableLogging = true
    },
    TargetMetadata = {
      TargetSchema = ""
      SupportLobs  = true
      FullLobMode  = false
      LobChunkSize = 64
      # ParallelLoadThreads  = 4
      # ParallelApplyThreads = 4
    }
  })
}

###################################
# RDS (source db)
###################################
resource "aws_db_subnet_group" "subnet_group_2" {
  name_prefix = "subnet-grp-"
  subnet_ids  = module.dms_vpc.private_subnets

  tags = {
    Name = "postgres-subnet-group"
  }
}

resource "aws_db_instance" "source_db" {
  identifier             = "source-db"
  allocated_storage      = 20
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  port                   = 5432
  db_name                = "demo_db"
  username               = local.db_creds_source.username
  password               = local.db_creds_source.password
  db_subnet_group_name   = aws_db_subnet_group.subnet_group_2.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  apply_immediately      = true
  skip_final_snapshot    = true
  parameter_group_name   = aws_db_parameter_group.rds_pg_for_cdc.name
  tags = merge(var.common_tags,
    {
      Name = "postgres"
    }
  )
}


# sec group for source db
resource "aws_security_group" "db_sg" {
  name_prefix = "db-sg-"
  vpc_id      = module.dms_vpc.vpc_id

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    security_groups = [
      aws_security_group.dms_sec_group.id,
      aws_security_group.ec2_sg.id
    ]
  }
  tags = merge(var.common_tags,
    {
      Name = "db-sg-"
    }
  )
}

###################################
# RDS parameter group
###################################
resource "aws_db_parameter_group" "rds_pg_for_cdc" {

  name   = "rds-pg-for-cdc"
  family = "postgres17"

  parameter {
    name         = "rds.logical_replication"
    value        = 1
    apply_method = "pending-reboot" # this is static parameter, which requires DB reboot (not immediately).
  }

  # maximum amount of WALs that replication slots can retain.
  parameter {
    name  = "max_slot_wal_keep_size" # this is dynamic parameter, can be applied immediately.
    value = 4096
  }

  # at least 1
  # parameter {
  #   name  = "max_replication_slots"
  #   value = "5"
  # }

  # at least 1
  # parameter {
  #   name  = "max_wal_senders"
  #   value = "1"
  # }
}

###################################
# Secret Mangager (RDS secret)
###################################
resource "random_string" "source_db" {
  length      = 8
  special     = false
  lower       = true
  min_numeric = 0
}

resource "aws_secretsmanager_secret" "masterdb_secret_2" {
  name_prefix = "source_db_"
}

resource "aws_secretsmanager_secret_version" "source_db_secret" {
  secret_id = aws_secretsmanager_secret.masterdb_secret_2.id
  secret_string = jsonencode({
    "username" = "postgres"
    "password" = "${random_string.source_db.id}"
  })
}

###################################
# Bastion host (private EC2)
###################################
resource "aws_network_interface" "ec2_nic" {
  subnet_id       = module.dms_vpc.private_subnets[0]
  security_groups = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_instance" "ec2" {
  ami                  = data.aws_ami.amazon_linux_2.id
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  instance_type        = var.instance_size
  user_data            = file("../scripts/user_data.sh")

  primary_network_interface {
    network_interface_id = aws_network_interface.ec2_nic.id
  }

  tags = merge(var.common_tags,
    {
      Name = "bastion-host"
    }
  )
}

resource "aws_security_group" "ec2_sg" {
  name_prefix = "ec2-SG-"
  vpc_id      = module.dms_vpc.vpc_id

  # needed for postgres
  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.dms_vpc.vpc_cidr_block]
  }

  # needed for ssm
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.dms_vpc.vpc_cidr_block]
  }

  # needed for s3 bucket linux repositories
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    prefix_list_ids = [aws_vpc_endpoint.s3_gateway_endpoint.prefix_list_id]
  }

  tags = merge(var.common_tags,
    {
      Name = "ec2-SG"
    }
  )
}

# linux repo
resource "aws_vpc_endpoint" "s3_gateway_endpoint" {
  vpc_id            = module.dms_vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.dms_vpc.private_route_table_ids

  tags = merge(var.common_tags,
    {
      Name = "S3-EP"
    }
  )
}

###################################
# Bastion instance profile (IAM)
###################################
resource "aws_iam_role" "instance" {
  name_prefix        = "InstProfileForEC2-"
  assume_role_policy = data.aws_iam_policy_document.sts.json
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name_prefix = "ec2_instance_profile_"
  role        = aws_iam_role.instance.name
}

resource "aws_iam_role_policy" "ssm_policy" {
  name = "ssm-policy"
  role = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.ssm.json
}

resource "aws_iam_role_policy" "dms_policy" {
  name = "dms-policy"
  role = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.dms.json
}

#################################################
# SSM Endpoints DMS VPC
#################################################
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = module.dms_vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.ssm_sec_grp.id]
  private_dns_enabled = true
  subnet_ids          = tolist(module.dms_vpc.private_subnets)
  tags = merge(var.common_tags,
    {
      Name = "SSM-EP"
    }
  )
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = module.dms_vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.ssm_sec_grp.id]
  private_dns_enabled = true
  subnet_ids          = tolist(module.dms_vpc.private_subnets)
  tags = merge(var.common_tags,
    {
      Name = "EC2Messages-EP"
    }
  )
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = module.dms_vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.ssm_sec_grp.id]
  private_dns_enabled = true
  subnet_ids          = tolist(module.dms_vpc.private_subnets)
  tags = merge(var.common_tags,
    {
      Name = "SSMMessages-EP"
    }
  )
}

resource "aws_security_group" "ssm_sec_grp" {
  name_prefix = "ssm-ep-sg-"
  vpc_id      = module.dms_vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.dms_vpc.vpc_cidr_block]
  }

  tags = merge(var.common_tags,
    {
      Name = "ssm-ep-sg"
    }
  )
}
