# Phase 3 — temporary legacy PostgreSQL source and AWS DMS

resource "aws_db_parameter_group" "source" {
  name   = "continuum-source-pg17"
  family = "postgres17"

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = { Name = "continuum-source-pg17" }
}

resource "aws_security_group" "source" {
  name_prefix = "continuum-source-"
  description = "Private legacy PostgreSQL source"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "continuum-source-sg" }
}

resource "aws_security_group" "dms" {
  name_prefix = "continuum-dms-"
  description = "Private DMS replication instance"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "continuum-dms-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "source_from_dms" {
  security_group_id            = aws_security_group.source.id
  referenced_security_group_id = aws_security_group.dms.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_egress_rule" "dms_to_source" {
  security_group_id            = aws_security_group.dms.id
  referenced_security_group_id = aws_security_group.source.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_ingress_rule" "db_from_dms" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.dms.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_egress_rule" "dms_to_db" {
  security_group_id            = aws_security_group.dms.id
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# Access to AWS service APIs through existing NAT gateways.
resource "aws_vpc_security_group_egress_rule" "dms_https" {
  security_group_id = aws_security_group.dms.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS for AWS service access"
}

resource "aws_db_instance" "source" {
  identifier = "continuum-legacy-source"

  engine         = "postgres"
  engine_version = "17"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  multi_az            = false
  publicly_accessible = false

  db_name  = "legacy"
  username = "legacy_admin"

  manage_master_user_password = true

  parameter_group_name   = aws_db_parameter_group.source.name
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.source.id]

  backup_retention_period    = 1
  deletion_protection        = false
  skip_final_snapshot        = true
  auto_minor_version_upgrade = false
  apply_immediately          = true

  tags = { Name = "continuum-legacy-source" }
}

resource "aws_dms_replication_subnet_group" "main" {
  replication_subnet_group_id          = "continuum-dms-subnets"
  replication_subnet_group_description = "Private DMS subnets"

  subnet_ids = [
    aws_subnet.app["a"].id,
    aws_subnet.app["b"].id
  ]

  tags = { Name = "continuum-dms-subnets" }
}

resource "aws_dms_replication_instance" "main" {
  depends_on                 = [aws_iam_role_policy_attachment.dms_vpc]
  replication_instance_id    = "continuum-dms"
  replication_instance_class = "dms.t3.small"
  engine_version             = "3.6.1"

  allocated_storage          = 50
  multi_az                   = false
  publicly_accessible        = false
  auto_minor_version_upgrade = false
  apply_immediately          = true

  replication_subnet_group_id = aws_dms_replication_subnet_group.main.id
  vpc_security_group_ids      = [aws_security_group.dms.id]

  tags = { Name = "continuum-dms" }
}
