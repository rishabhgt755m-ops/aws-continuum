# Phase 3 temporary SSM-based database preparation access.
# Remove after migration testing.

resource "aws_vpc_security_group_ingress_rule" "source_from_app_test" {
  security_group_id            = aws_security_group.source.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "Temporary Phase 3 database preparation"
}

resource "aws_vpc_security_group_egress_rule" "app_to_source_test" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.source.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "Temporary Phase 3 source access"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app_test" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "Temporary Phase 3 target validation"
}

resource "aws_vpc_security_group_egress_rule" "app_to_db_test" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "Temporary Phase 3 target access"
}
