# This file manages the prefect2 testing env that act as a PoC for prefect2 deployment
# This environment will contain a vpc with a subnet, and two ec2 instances in the subnet
# both instances will be accessible throgh ssh using the key pair wa-ops

# lets create a vpc
resource "aws_vpc" "prefect2_vpc" {
  cidr_block = "172.16.0.0/16"

  tags = {
    Name = "prefect2-vpc"
    Project = "prefect2"
    Team = "engineering"
    Status = "proof-of-concept"
  }
}

# then a private subnet within the vpc
resource "aws_subnet" "prefect2_private_subnet" {
  vpc_id = aws_vpc.prefect2_vpc.id
  cidr_block = "172.16.10.0/26"
  availability_zone = "us-east-1a"

  #map_public_ip_on_launch =  # so the instances can be accessed from the internet

  tags = {
    Name = "prefect2-private-subnet"
    Project = "prefect2"
    Team = "engineering"
    Status = "proof-of-concept"
  }
}

# and a public subnet within the vpc
resource "aws_subnet" "prefect2_public_subnet" {
  vpc_id = aws_vpc.prefect2_vpc.id
  cidr_block = "172.16.10.64/26"
  availability_zone = "us-east-1a"

  map_public_ip_on_launch =  true # so the instances can be accessed from the internet

  tags = {
    Name = "prefect2-public-subnet"
    Project = "prefect2"
    Team = "engineering"
    Status = "proof-of-concept"
  }
}

# now add an internet gateway to the vpc
resource "aws_internet_gateway" "prefect2_igw" {
  vpc_id = aws_vpc.prefect2_vpc.id

  tags = {
    Name = "prefect2-igw"
    Project = "prefect2"
    Team = "engineering"
    Status = "proof-of-concept"
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
    Name = "prefect2-route-table"
    Project = "prefect2"
    Team = "engineering"
    Status = "proof-of-concept"
  }
}

# and associate the route
resource "aws_route_table_association" "prefect2_route_table_association" {
  subnet_id = aws_subnet.prefect2_public_subnet.id
  route_table_id = aws_route_table.prefect2_route_table.id
}
 

# lets create a security group for the ec2 instances
# this security group will allow ssh access from the outside
resource "aws_security_group" "prefect2_sg" {
  name = "prefect2_sg"
  description = "prefect2 security group"
  vpc_id = aws_vpc.prefect2_vpc.id

  ingress {
    description = "ssh"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # from anywhere
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # to anywhere
  }

  tags = {
    Name = "prefect2-sg"
    Project = "prefect2"
    Team = "engineering"
    Status = "proof-of-concept"
  }
}


# lets create two micro ec2 instances within our subnet
# belonging to the prefect2 security group
# one for the controller, other for the docker runner
resource "aws_instance" "prefect2_controller" {
  count = 2  # the two ec2 instances
  ami = "ami-0557a15b87f6559cf"  # ubunut 22.04 server
  instance_type = "t2.micro"
  key_name = "wa-ops"
  subnet_id = aws_subnet.prefect2_public_subnet.id
  vpc_security_group_ids = [aws_security_group.prefect2_sg.id]

  associate_public_ip_address = true

  tags = {
    Name = "prefect2-ec2-${count.index}"
    Project = "prefect2"
    Team = "engineering"
    Status = "proof-of-concept"

  }
}

