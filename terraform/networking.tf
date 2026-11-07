locals {
  azs = {
    a = "eu-west-1a"
    b = "eu-west-1b"
  }

  subnet_cidrs = {
    public = {
      a = "10.30.0.0/24"
      b = "10.30.1.0/24"
    }
    app = {
      a = "10.30.10.0/24"
      b = "10.30.11.0/24"
    }
    db = {
      a = "10.30.20.0/24"
      b = "10.30.21.0/24"
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.30.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "continuum-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "continuum-igw" }
}

resource "aws_subnet" "public" {
  for_each = local.azs

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value
  cidr_block              = local.subnet_cidrs.public[each.key]
  map_public_ip_on_launch = false

  tags = { Name = "continuum-public-${each.key}" }
}

resource "aws_subnet" "app" {
  for_each = local.azs

  vpc_id            = aws_vpc.main.id
  availability_zone = each.value
  cidr_block        = local.subnet_cidrs.app[each.key]

  tags = { Name = "continuum-app-${each.key}" }
}

resource "aws_subnet" "db" {
  for_each = local.azs

  vpc_id            = aws_vpc.main.id
  availability_zone = each.value
  cidr_block        = local.subnet_cidrs.db[each.key]

  tags = { Name = "continuum-db-${each.key}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "continuum-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each = local.azs

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  for_each = local.azs
  domain   = "vpc"

  tags = { Name = "continuum-nat-eip-${each.key}" }
}

resource "aws_nat_gateway" "main" {
  for_each = local.azs

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  depends_on = [aws_internet_gateway.main]

  tags = { Name = "continuum-nat-${each.key}" }
}

resource "aws_route_table" "app" {
  for_each = local.azs

  vpc_id = aws_vpc.main.id

  tags = { Name = "continuum-app-rt-${each.key}" }
}

resource "aws_route" "app_internet" {
  for_each = local.azs

  route_table_id         = aws_route_table.app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[each.key].id
}

resource "aws_route_table_association" "app" {
  for_each = local.azs

  subnet_id      = aws_subnet.app[each.key].id
  route_table_id = aws_route_table.app[each.key].id
}

resource "aws_route_table" "db" {
  for_each = local.azs

  vpc_id = aws_vpc.main.id

  tags = { Name = "continuum-db-rt-${each.key}" }
}

resource "aws_route_table_association" "db" {
  for_each = local.azs

  subnet_id      = aws_subnet.db[each.key].id
  route_table_id = aws_route_table.db[each.key].id
}
