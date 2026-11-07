resource "aws_db_subnet_group" "main" {
  name = "continuum-db-subnets"

  subnet_ids = [
    aws_subnet.db["a"].id,
    aws_subnet.db["b"].id
  ]

  tags = {
    Name = "continuum-db-subnets"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "continuum-postgres"

  engine         = "postgres"
  engine_version = "17"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  multi_az            = true
  publicly_accessible = false

  db_name  = "continuum"
  username = "continuum_admin"

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]

  backup_retention_period = 1
  deletion_protection     = false
  skip_final_snapshot     = true
  copy_tags_to_snapshot   = true

  auto_minor_version_upgrade = false
  apply_immediately          = true

  tags = {
    Name = "continuum-postgres"
  }
}
