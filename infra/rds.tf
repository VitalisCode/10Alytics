resource "aws_db_subnet_group" "db_subnet" {
  name       = "devops-db-subnet"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_db_instance" "postgres" {
  identifier         = "devops-postgres"
  engine             = "postgres"
  instance_class     = "db.t3.micro"
  allocated_storage  = 20

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids = [module.vpc.default_security_group_id]

  skip_final_snapshot = true
  publicly_accessible = false
}