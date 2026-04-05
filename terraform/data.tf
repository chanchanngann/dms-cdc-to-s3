###################################
# SSM
###################################
data "aws_iam_policy_document" "ssm" {
  statement {
    sid    = "1"
    effect = "Allow"
    actions = [
      "ssm:DescribeAssociation",
      "ssm:GetDeployablePatchSnapshotForInstance",
      "ssm:GetDocument",
      "ssm:DescribeDocument",
      "ssm:GetManifest",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:ListAssociations",
      "ssm:ListInstanceAssociations",
      "ssm:PutInventory",
      "ssm:PutComplianceItems",
      "ssm:PutConfigurePackageResult",
      "ssm:UpdateAssociationStatus",
      "ssm:UpdateInstanceAssociationStatus",
      "ssm:UpdateInstanceInformation"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "2"
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "3"
    effect = "Allow"
    actions = [
      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply"
    ]
    resources = ["*"]
  }
}

###################################
# DMS
###################################
data "aws_iam_policy_document" "dms" {
  statement {
    sid    = "1"
    effect = "Allow"
    actions = [
      "dms:*"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "dms_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["dms.amazonaws.com"]
      type        = "Service"
    }
  }
}

###################################
# Bastion
###################################
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}

data "aws_iam_policy_document" "sts" {
  statement {
    sid    = "1"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

###################################
# S3 gateway
###################################
data "aws_iam_policy_document" "s3_gateway" {
  statement {
    sid    = "1"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = [
      "s3:GetObject"
    ]
    resources = ["arn:aws:s3:::amazonlinux.${var.region}.amazonaws.com/*",
    "arn:aws:s3:::amazonlinux-2-repos-${var.region}/*"]
  }
}

###################################
# DMS glue access
###################################

# data "aws_iam_policy_document" "dms_glue_access" {
#   statement {
#     effect = "Allow"
#     actions = [
#       "glue:CreateDatabase", 
#       "glue:GetDatabase", 
#       "glue:CreateTable", 
#       "glue:DeleteTable", 
#       "glue:UpdateTable", 
#       "glue:GetTable", 
#       "glue:BatchCreatePartition", 
#       "glue:CreatePartition", 
#       "glue:UpdatePartition", 
#       "glue:GetPartition", 
#       "glue:GetPartitions", 
#       "glue:BatchGetPartition"
#     ]
#     resources = ["*"]
#   }
# }

# data "aws_iam_policy_document" "dms_s3_access" {
#   statement {
#     effect = "Allow"
#     actions = [
#       "s3:CreateBucket",
#       "s3:ListBucket",
#       "s3:DeleteBucket",
#       "s3:GetBucketLocation",
#       "s3:GetObject",
#       "s3:PutObject",
#       "s3:DeleteObject",
#       "s3:GetObjectVersion",
#       "s3:GetBucketPolicy",
#       "s3:PutBucketPolicy",
#       "s3:GetBucketAcl",
#       "s3:PutBucketVersioning",
#       "s3:GetBucketVersioning",
#       "s3:PutLifecycleConfiguration",
#       "s3:GetLifecycleConfiguration",
#       "s3:DeleteBucketPolicy",
#       "s3:ListBucketMultipartUploads", 
#       "s3:ListMultipartUploadParts", 
#       "s3:AbortMultipartUpload" 
#     ]
#     resources = ["arn:aws:s3:::${var.dms_s3_bucket}", 
#                 "arn:aws:s3:::${var.dms_s3_bucket}/*" ]
#   }
# }

# data "aws_iam_policy_document" "dms_athena_access" {
#   statement {
#     effect = "Allow"
#     actions = [
#       "athena:StartQueryExecution",
#       "athena:GetQueryExecution", 
#       "athena:CreateWorkGroup"
#     ]
#     resources = ["*"]
#   }
# }
