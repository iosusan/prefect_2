# This file manages the prefect2 testing env that act as a PoC for prefect2 deployment
# This environment will contain a vpc with a subnet, and two ec2 instances in the subnet
# both instances will be accessible throgh ssh using the key pair wa-ops
# In addition we want SSM Agent installed in both instances, 
# so we can use SSM to manage the instances
# And finally a role that includes AmazonSSMManagedInstanceCore

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  required_version = ">= 1.2.0"
}

# lets create a vpc
resource "aws_vpc" "prefect2_vpc" {
  cidr_block = "172.16.0.0/16"

  tags = {
    Name    = "prefect2-vpc"
    Project = "prefect2"
    Team    = "engineering"
    Status  = "proof-of-concept"
  }
}


# then a private subnet within the vpc
resource "aws_subnet" "prefect2_private_subnet" {
  vpc_id            = aws_vpc.prefect2_vpc.id
  cidr_block        = "172.16.10.0/26"
  availability_zone = "us-east-1a"

  #map_public_ip_on_launch =  # so the instances can be accessed from the internet

  tags = {
    Name    = "prefect2-private-subnet"
    Project = "prefect2"
    Team    = "engineering"
    Status  = "proof-of-concept"
  }
}

# and a public subnet within the vpc
resource "aws_subnet" "prefect2_public_subnet" {
  vpc_id            = aws_vpc.prefect2_vpc.id
  cidr_block        = "172.16.10.64/26"
  availability_zone = "us-east-1a"

  map_public_ip_on_launch = true # so the instances can be accessed from the internet

  tags = {
    Name    = "prefect2-public-subnet"
    Project = "prefect2"
    Team    = "engineering"
    Status  = "proof-of-concept"
  }
}

# now add an internet gateway to the vpc
resource "aws_internet_gateway" "prefect2_igw" {
  vpc_id = aws_vpc.prefect2_vpc.id

  tags = {
    Name    = "prefect2-igw"
    Project = "prefect2"
    Team    = "engineering"
    Status  = "proof-of-concept"
  }
}

# add a default route to the internet gateway
resource "aws_route_table" "prefect2_route_table" {
  vpc_id = aws_vpc.prefect2_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prefect2_igw.id
  }

  tags = {
    Name    = "prefect2-route-table"
    Project = "prefect2"
    Team    = "engineering"
    Status  = "proof-of-concept"
  }
}

# and associate the route
resource "aws_route_table_association" "prefect2_public_route_table_association" {
  subnet_id      = aws_subnet.prefect2_public_subnet.id
  route_table_id = aws_route_table.prefect2_route_table.id
}

# lets create a NAT gateway for the private subnet
# first we need an elastic ip
resource "aws_eip" "prefect2_nat_eip" {
  vpc = true

  tags = {
    Name    = "prefect2-nat-eip"
    Project = "prefect2"
    Team    = "engineering"
    Status  = "proof-of-concept"
  }
}

# now the NAT gateway
resource "aws_nat_gateway" "prefect2_nat_gateway" {
  allocation_id = aws_eip.prefect2_nat_eip.id
  subnet_id     = aws_subnet.prefect2_public_subnet.id

  tags = {
    Name    = "prefect2-nat-gateway"
    Project = "prefect2"
    Team    = "engineering"
    Status  = "proof-of-concept"
  }
}

# and a route to the NAT gateway
resource "aws_route_table" "prefect2_private_route_table" {
  vpc_id = aws_vpc.prefect2_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.prefect2_nat_gateway.id
  }

  tags = {
    Name    = "prefect2-private-route-table"
    Project = "prefect2"
    Team    = "engineering"
    Status  = "proof-of-concept"
  }
}

# finally we associate the private route table with the private subnet
resource "aws_route_table_association" "prefect2_private_route_table_association" {
  subnet_id      = aws_subnet.prefect2_private_subnet.id
  route_table_id = aws_route_table.prefect2_private_route_table.id
}



# lets create a security group for the ec2 instances
# this security group will allow ssh access from the outside
resource "aws_security_group" "prefect2_sg" {
  name        = "prefect2_sg"
  description = "prefect2 security group"
  vpc_id      = aws_vpc.prefect2_vpc.id

  ingress {
    description = "ssh acceess"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # from anywhere
  }

  ingress {
    description = "prefect2 UI acceess"
    from_port   = 4200
    to_port     = 4200
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # from within the vpc
  }

  egress {
    description = "all traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # to anywhere
  }

  tags = {
    Name    = "prefect2-sg"
    Project = "prefect2"
    Team    = "engineering"
    Status  = "proof-of-concept"
  }
}



# the AWS keypair we will use
resource "aws_key_pair" "wa-ops" {
  public_key = file("~/.ssh/wa-ops.pub")
}

# lets create two micro ec2 instances within our subnet
# belonging to the prefect2 security group
# one for the controller, other for the docker runner
resource "aws_instance" "prefect2_worker" {
  count                  = 2                       # the two ec2 instances
  ami                    = "ami-0557a15b87f6559cf" # ubunut 22.04 server
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.prefect2_public_subnet.id
  vpc_security_group_ids = [aws_security_group.prefect2_sg.id]

  iam_instance_profile = aws_iam_instance_profile.prefect2_ec2_ssm_instance_profile.name
  key_name             = "wa-ops"

  associate_public_ip_address = true # this is required to acceess the instances from the internet

  # this is a security restriction to prevent the metadata service from being accessed freely
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional" #"required"
  }

  tags = {
    Name    = "prefect2-ec2-${count.index}"
    Project = "prefect2"
    Team    = "engineering"
    Status  = "proof-of-concept"

  }

  # and run the ssm agent installation script
  user_data = data.template_file.ssmagent.rendered

}

