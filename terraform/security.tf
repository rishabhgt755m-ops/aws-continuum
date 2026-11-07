resource "aws_security_group" "alb" {
  name_prefix = "continuum-alb-"
  description = "Public ALB security group"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "continuum-alb-sg" }
}

resource "aws_security_group" "app" {
  name_prefix = "continuum-app-"
  description = "Private application security group"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "continuum-app-sg" }
}

resource "aws_security_group" "db" {
  name_prefix = "continuum-db-"
  description = "Private PostgreSQL security group"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "continuum-db-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_outbound" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Temporary lab outbound access; tighten in later phases"
}
