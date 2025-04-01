terraform {
  required_version = ">= 1.5.0"  # 최소 Terraform 버전 1.5.0 이상
}
provider "aws" {  }

# VPC 생성
resource "aws_vpc" "main" {
  cidr_block = "10.3.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

# Public Subnet 생성
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.3.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "CH3-Public-EC2"
  }
}

# Private Subnet 생성
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.3.2.0/24"
  availability_zone       = "ap-northeast-2c"
  tags = {
    Name = "CH3-Private-EC2"
  }
}

# Internet Gateway 생성
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "CH3-IGW"
  }
}

# Elastic IP 생성 (NAT Gateway용)
resource "aws_eip" "nat" {
  vpc = true
}

# NAT Gateway 생성
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags = {
    Name = "CH3-NAT-GW"
  }
}

# Public Route Table 생성
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "CH3-Public-RT"
  }
}

# Public Route Table에 인터넷 게이트웨이 연결
resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Public Subnet에 Public Route Table 연결
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private Route Table 생성
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "CH3-Private-RT"
  }
}

# Private Route Table에 NAT Gateway 연결
resource "aws_route" "private_nat_gw" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

# Private Subnet에 Private Route Table 연결
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Security Group for Public Subnet
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.main.id
  name   = "public-sg"
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # SSH 접근을 위해 모든 IP 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for Private Subnet
resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.main.id
  name   = "private-sg"
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # SSH 접근을 위해 모든 IP 허용
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# NACL 생성 (Public Subnet용)
resource "aws_network_acl" "public_acl" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "public-acl"
  }
}

# NACL 규칙 추가 (Public Subnet용)
resource "aws_network_acl_rule" "public_acl_allow_inbound" {
  network_acl_id = aws_network_acl.public_acl.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 65535
}

resource "aws_network_acl_rule" "public_acl_allow_outbound" {
  network_acl_id = aws_network_acl.public_acl.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 65535
}

# NACL (Private Subnet용)
resource "aws_network_acl" "private_acl" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "private-acl"
  }
}

# NACL 규칙 추가 (Private Subnet용)
resource "aws_network_acl_rule" "private_acl_allow_inbound" {
  network_acl_id = aws_network_acl.private_acl.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_acl_allow_outbound" {
  network_acl_id = aws_network_acl.private_acl.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 65535
}

# EC2 인스턴스 (Public Subnet)
resource "aws_instance" "public_ec2" {
  ami           = "ami-070e986143a3041b6"  # 예시로 Amazon Linux 2 AMI (리전마다 다를 수 있음)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  key_name = "mykey"  # key pair 이름 지정
  associate_public_ip_address = true
  tags = {
    Name = "public-ec2"
  }
}

# EC2 인스턴스 (Private Subnet)
resource "aws_instance" "private_ec2" {
  ami           = "ami-070e986143a3041b6"  # 예시로 Amazon Linux 2 AMI (리전마다 다를 수 있음)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name = "mykey"  # key pair 이름 지정
  associate_public_ip_address = false
  tags = {
    Name = "private-ec2"
  }
}
