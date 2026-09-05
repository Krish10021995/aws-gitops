resource "aws_db_subnet_group" "this" {
  name       = "rds-${var.environment}"
  subnet_ids = var.subnet_ids
  tags       = { Name = "rds-subnet-group-${var.environment}" }
}

resource "aws_security_group" "rds" {
  name   = "rds-${var.environment}"
  vpc_id = var.vpc_id

  tags = { Name = "rds-sg-${var.environment}" }
}

resource "aws_security_group_rule" "postgres_from_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.app_security_group
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
}

resource "aws_db_instance" "postgres" {
  identifier              = "demoapp-${var.environment}"
  engine                  = "postgres"
  engine_version          = "15.8"
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  storage_type            = "gp3"
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  skip_final_snapshot     = true
  backup_retention_period = 7
  storage_encrypted       = true
  multi_az                = false

  tags = { Name = "demoapp-${var.environment}" }
}

output "endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "database_name" {
  value = aws_db_instance.postgres.db_name
}

output "security_group_id" {
  value = aws_security_group.rds.id
}