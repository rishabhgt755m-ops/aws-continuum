# Phase 3 — DMS endpoint credentials stay in Secrets Manager.

data "aws_secretsmanager_secret" "dms_source" {
  name = "continuum/dms/source"
}

data "aws_secretsmanager_secret" "dms_target" {
  name = "continuum/dms/target"
}

resource "aws_iam_role" "dms_secrets" {
  name = "continuum-dms-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "dms.eu-west-1.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "dms_secrets" {
  name = "continuum-dms-secret-read"
  role = aws_iam_role.dms_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]
      Resource = [
        data.aws_secretsmanager_secret.dms_source.arn,
        data.aws_secretsmanager_secret.dms_target.arn
      ]
    }]
  })
}

# Private access to Secrets Manager for the DMS instance.

resource "aws_security_group" "dms_secrets_endpoint" {
  name_prefix = "continuum-dms-secrets-"
  description = "Secrets Manager endpoint access from DMS"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "continuum-dms-secrets-endpoint" }
}

resource "aws_vpc_security_group_ingress_rule" "dms_secrets_https" {
  security_group_id            = aws_security_group.dms_secrets_endpoint.id
  referenced_security_group_id = aws_security_group.dms.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_endpoint" "dms_secrets" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-west-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.app["a"].id,
    aws_subnet.app["b"].id
  ]

  security_group_ids = [
    aws_security_group.dms_secrets_endpoint.id
  ]

  tags = { Name = "continuum-dms-secrets-vpce" }
}

resource "aws_dms_endpoint" "source" {
  endpoint_id   = "continuum-source"
  endpoint_type = "source"
  engine_name   = "postgres"
  database_name = "legacy"

  secrets_manager_arn             = data.aws_secretsmanager_secret.dms_source.arn
  secrets_manager_access_role_arn = aws_iam_role.dms_secrets.arn

  ssl_mode = "require"

  extra_connection_attributes = "secretsManagerEndpointOverride=${aws_vpc_endpoint.dms_secrets.dns_entry[0].dns_name}"

  postgres_settings {
    capture_ddls = false
    plugin_name  = "test-decoding"
  }

  depends_on = [aws_iam_role_policy.dms_secrets]

  tags = { Name = "continuum-source-endpoint" }
}

resource "aws_dms_endpoint" "target" {
  endpoint_id   = "continuum-target"
  endpoint_type = "target"
  engine_name   = "postgres"
  database_name = "continuum"

  secrets_manager_arn             = data.aws_secretsmanager_secret.dms_target.arn
  secrets_manager_access_role_arn = aws_iam_role.dms_secrets.arn

  ssl_mode = "require"

  extra_connection_attributes = "secretsManagerEndpointOverride=${aws_vpc_endpoint.dms_secrets.dns_entry[0].dns_name}"

  depends_on = [aws_iam_role_policy.dms_secrets]

  tags = { Name = "continuum-target-endpoint" }
}
