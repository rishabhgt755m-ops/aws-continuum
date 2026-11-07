data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_iam_role_policy" "app_proxy_connect" {
  name = "continuum-app-proxy-connect"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["rds-db:connect"]
      Resource = "arn:aws:rds-db:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:dbuser:${split(":", aws_db_proxy.app.arn)[6]}/continuum_app"
    }]
  })
}
