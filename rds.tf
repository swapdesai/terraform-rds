provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "ap-southeast-2"
}

# Create VPC
resource "aws_vpc" "rds_vpc" {
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true

	tags {
    Name = "rds_vpc"
  }
}

# Public subnets
resource "aws_subnet" "rds_public" {
	vpc_id = "${aws_vpc.rds_vpc.id}"

	cidr_block = "10.0.0.0/24"
	#availability_zone = "ap-southeast-2a"

	tags {
    Name = "rds_subnet_public"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "rds_internet_gateway" {
	vpc_id = "${aws_vpc.rds_vpc.id}"

	tags {
    Name = "rds_internet_gateway"
  }
}

# Routing table for public subnet
resource "aws_route_table" "rds_public" {
	vpc_id = "${aws_vpc.rds_vpc.id}"

  route {
		cidr_block = "0.0.0.0/0"
		gateway_id = "${aws_internet_gateway.rds_internet_gateway.id}"
	}

	tags {
    Name = "rds_route_table_public"
  }
}

# Route Table association to the subnet
resource "aws_route_table_association" "rds_public" {
	subnet_id = "${aws_subnet.rds_public.id}"
	route_table_id = "${aws_route_table.rds_public.id}"
}

# Create Security Group
resource "aws_security_group" "rds_security_group_public" {
  vpc_id = "${aws_vpc.rds_vpc.id}"

  name = "rds_ssh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

# Private subsets
resource "aws_subnet" "rds_private_1" {
	vpc_id = "${aws_vpc.rds_vpc.id}"

	cidr_block = "10.0.1.0/24"
	availability_zone = "ap-southeast-2a"

	tags {
    Name = "rds_subnet_private_1"
  }
}

# atleast 2 AZs for RDS deployment to subnet groups
resource "aws_subnet" "rds_private_2" {
	vpc_id = "${aws_vpc.rds_vpc.id}"

	cidr_block = "10.0.3.0/24"
	availability_zone = "ap-southeast-2b"

	tags {
    Name = "rds_subnet_private_2"
  }
}

# Routing table for private subnet
resource "aws_route_table" "rds_private" {
	vpc_id = "${aws_vpc.rds_vpc.id}"

	tags {
    Name = "rds_route_table_private"
  }
}

# Route Table association to the subnet
resource "aws_route_table_association" "rds_private_1" {
	subnet_id = "${aws_subnet.rds_private_1.id}"
	route_table_id = "${aws_route_table.rds_private.id}"
}


# Route Table association to the subnet
resource "aws_route_table_association" "rds_private_2" {
	subnet_id = "${aws_subnet.rds_private_2.id}"
	route_table_id = "${aws_route_table.rds_private.id}"
}

# Create Security Group
resource "aws_security_group" "rds_security_group_private" {
  vpc_id = "${aws_vpc.rds_vpc.id}"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

# Create SSH key pair
resource "aws_key_pair" "deployer" {
  key_name   = "rds_key_name"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCx0PZMUM+ML5K3SW1mMHiB3L/v3Xh91sAiHFlt7Qf4++w999RMANP5GIbLRyYqc1KqJlreJQsv1ChuLn059gNdtz4l551jw56lAotuFUIOZ3LhTlw1XlX/bQTYGJAfxzgqs3BMPVBG3eZVtqY3gk2cI+w+SvAy0WYGVrZPuPJfmPL5gKU+ys8IvhLUqXKfUXWx8tu77Ni71/WjRfPqNHyIr6sPt6K03LOF03Qm9EQWHolf1wKesg+pUs1i0HEr0DC34WYWJUiDG1f/flkPvKqQa57rmIX2gMZicWEzyInPqZc8+dXDCoO4khjPzb0U1CImAiUYphhESIOOZ1rhVc+X swadesai@au10154"
}


# Create EC2 instance
resource "aws_instance" "web" {
  ami           = "ami-30041c53"
  instance_type = "t2.micro"
  key_name      = "rds_key_name"

  # When using subnet_id and using a security groups from a non-default VPC, need to use group id instead of name
  #security_groups = [ "rds_security_group" ]
  security_groups = [ "${aws_security_group.rds_security_group_public.id}" ]

  subnet_id = "${aws_subnet.rds_public.id}"

  associate_public_ip_address = true

  tags {
    name = "rds_instance"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds"
  subnet_ids = [ "${aws_subnet.rds_private_1.id}", "${aws_subnet.rds_private_2.id}" ]

  tags {
    Name = "My DB subnet group"
  }
}

resource "aws_db_instance" "rds" {
  allocated_storage    = 5
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "9.6.2"
  instance_class       = "db.t2.micro"
  name                 = "rds"

  multi_az = false

  username             = "${var.rds_username}"
  password             = "${var.rds_password}"

  db_subnet_group_name = "${aws_db_subnet_group.rds_subnet_group.name}"

  vpc_security_group_ids = [ "${aws_security_group.rds_security_group_private.id}" ]
}
