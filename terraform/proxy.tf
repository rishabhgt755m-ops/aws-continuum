# Secret metadata only. Password values are populated
# separately and never managed through Terraform state.
resource "aws_secretsmanager_secret" "app" {
  name                    = "continuum/app/db-credentials"
  description             = "Restricted PostgreSQL application credentials"
  recovery_window_in_days = 0

  tags = { Name = "continuum-app-db-credentials" }
}

resource "aws_security_group" "proxy" {
  name_prefix = "continuum-proxy-"
  description = "Private RDS Proxy security group"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "continuum-proxy-sg" }
}

resource "aws_vpc_security_group_egress_rule" "app_to_proxy" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.proxy.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "proxy_from_app" {
  security_group_id            = aws_security_group.proxy.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "proxy_to_db" {
  security_group_id            = aws_security_group.proxy.id
  referenced_security_group_id = aws_security_group.db.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_proxy" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.proxy.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_iam_role" "proxy" {
  name_prefix = "continuum-rds-proxy-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "proxy_secret" {
  name = "continuum-proxy-secret-access"
  role = aws_iam_role.proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.app.arn
    }]
  })
}

resource "aws_db_proxy" "app" {
  name                   = "continuum-db-proxy"
  engine_family          = "POSTGRESQL"
  role_arn               = aws_iam_role.proxy.arn
  require_tls            = true
  idle_client_timeout    = 1800
  vpc_security_group_ids = [aws_security_group.proxy.id]

  vpc_subnet_ids = [
    aws_subnet.app["a"].id,
    aws_subnet.app["b"].id
  ]

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "REQUIRED"
    secret_arn  = aws_secretsmanager_secret.app.arn
  }

  depends_on = [aws_iam_role_policy.proxy_secret]

  tags = { Name = "continuum-db-proxy" }
}

resource "aws_db_proxy_target" "postgres" {
  db_proxy_name          = aws_db_proxy.app.name
  target_group_name      = "default"
  db_instance_identifier = aws_db_instance.postgres.identifier
}
