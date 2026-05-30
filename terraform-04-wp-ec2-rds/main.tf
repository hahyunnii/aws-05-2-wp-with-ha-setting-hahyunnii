# ─────────────────────────────────────────────────────────────────────────────
# Data Sources - discover existing AWS infrastructure
# ─────────────────────────────────────────────────────────────────────────────

# Read the default VPC so we can reference its ID throughout the config.
data "aws_vpc" "default" {
  default = true
}

# Read all subnets that belong to the default VPC.
data "aws_subnets" "default_vpc" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Read the latest Amazon Linux 2023 AMI from the public SSM parameter namespace.
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  # Sort subnet IDs for deterministic ordering; RDS subnet group needs >= 2 subnets.
  subnet_ids = sort(data.aws_subnets.default_vpc.ids)

  common_tags = {
    Course  = "cloud-computing-aws"
    Lab     = "week-12-wp-ec2-rds"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Security Group - WordPress EC2 (web tier)
# Allows: HTTP/80 from internet, optional SSH/22 from internet
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_security_group" "wordpress" {
  name        = "${var.name_prefix}-wp-sg"
  description = "Allow HTTP traffic to the WordPress EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow inbound HTTP from the internet for WordPress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH for troubleshooting - narrow or remove in production"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic for package installation and RDS access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-wp-sg"
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# Security Group - RDS MySQL (database tier)
# Allows: TCP/3306 ONLY from the WordPress EC2 security group - never from 0.0.0.0/0
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Allow MySQL traffic only from the WordPress EC2 security group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Allow MySQL from the WordPress EC2 SG only - no public access"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-rds-sg"
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# DB Subnet Group - required by RDS even in the default VPC
# Uses all available subnets for AZ coverage
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "wordpress" {
  name        = "${var.name_prefix}-db-subnet-group"
  description = "Subnet group for the WordPress RDS instance"
  subnet_ids  = local.subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# RDS MySQL Instance - private, managed database tier
# CRITICAL: publicly_accessible = false - never change this
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_db_instance" "wordpress" {
  identifier        = "${var.name_prefix}-rds"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_master_password

  db_subnet_group_name   = aws_db_subnet_group.wordpress.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # SECURITY BOUNDARY: RDS must never be publicly accessible
  publicly_accessible = false

  # Skip final snapshot for lab environments to allow clean destroy
  skip_final_snapshot = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-rds"
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# EC2 Instance - WordPress web tier
# Bootstrapped via user_data: installs Apache, PHP, WordPress, connects to RDS
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_instance" "wordpress" {
  ami           = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.instance_type
  subnet_id     = local.subnet_ids[0]

  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.wordpress.id]

  # Pass the RDS endpoint into the bootstrap script via templatefile
  user_data = templatefile("${path.module}/user-data.sh", {
    db_host     = aws_db_instance.wordpress.address
    db_name     = var.db_name
    db_user     = var.db_username
    db_password = var.db_master_password
    name_prefix = var.name_prefix
  })

  # No IAM instance profile needed - MySQL password auth is used, not IAM DB auth
  # iam_instance_profile = ""  # intentionally empty

  key_name = var.key_name != "" ? var.key_name : null

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-wordpress"
  })

  # Ensure RDS is ready before EC2 tries to connect during bootstrap
  depends_on = [aws_db_instance.wordpress]
}
