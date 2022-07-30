terraform {

 required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

#  provider "aws" {
 #   region     = "ca-central-1"
 #  }
}

#Creates a VPC
resource "aws_vpc" "terraform_lab" {
  cidr_block = "10.0.0.0/16"
}

#Creates public subnet 1
  resource "aws_subnet" "pub_sub1" {
  vpc_id     = aws_vpc.terraform_lab.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ca-central-1a"
  enable_resource_name_dns_a_record_on_launch = true
  map_public_ip_on_launch = true

  tags = {
    Name = "pub_sub1"
  }
 }

#Creates public subnet 2
  resource "aws_subnet" "pub_sub2" {
  vpc_id     = aws_vpc.terraform_lab.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ca-central-1b"
  enable_resource_name_dns_a_record_on_launch = true
  map_public_ip_on_launch = true

  tags = {
    Name = "pub_sub2"
  }
}

#Creates private subnet 1
  resource "aws_subnet" "priv_sub1" {
  vpc_id     = aws_vpc.terraform_lab.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "ca-central-1a"
  enable_resource_name_dns_a_record_on_launch = true
  map_public_ip_on_launch = false

  tags = {
    Name = "priv_sub1"
  }
}

#Creates private subnet 2
  resource "aws_subnet" "priv_sub2" {
  vpc_id     = aws_vpc.terraform_lab.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "ca-central-1b"
  enable_resource_name_dns_a_record_on_launch = true
  map_public_ip_on_launch = false

  tags = {
    Name = "priv_sub2"
  }
}

#Creates an Internet Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.terraform_lab.id

  tags = {
    Name = "Terraform IGW"
  }
}

#Attaches Internet Gateway to VPC

resource "aws_internet_gateway_attachment" "gw_attachement" {
  internet_gateway_id = aws_internet_gateway.gw.id
  vpc_id              = aws_vpc.terraform_lab.id
}

#Creates Elastic IP for nat gateway
resource "aws_eip" "ip_nat_gw" {
 # instance = aws_instance.web.id
  vpc      = true
}



#Creates a nat gateway for AZ1
resource "aws_nat_gateway" "terraform_nat_gw" {
  allocation_id = aws_eip.ip_nat_gw.id
  subnet_id     = aws_subnet.pub_sub1.id

  tags = {
    Name = "gw NAT-AZ1"
  }
  depends_on = [aws_internet_gateway.gw]
}

#Creates a nat gateway for AZ2
#resource "aws_nat_gateway" "terraform_nat_gw" {
#  allocation_id = aws_eip.pub_sub2.id
#  subnet_id     = aws_subnet.pub_sub2.id

#  tags = {
#    Name = "gw NAT-AZ2"
#  }
#  depends_on = [aws_internet_gateway.gw]
#}


#Creates public route table
resource "aws_route_table" "public_RT" {
  vpc_id = aws_vpc.terraform_lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

#Creates private route table1 via nat gateway
resource "aws_route_table" "private_RT1" {
  vpc_id = aws_vpc.terraform_lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

#Creates private route table2 via nat gateway
resource "aws_route_table" "private_RT2" {
  vpc_id = aws_vpc.terraform_lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

}
#Creates private route table2 via nat gateway
resource "aws_route_table_association" "pub1" {
  subnet_id      = aws_subnet.pub_sub1.id
  route_table_id = aws_route_table.public_RT.id
}

resource "aws_route_table_association" "pub2" {
  subnet_id      = aws_subnet.pub_sub2.id
  route_table_id = aws_route_table.public_RT.id
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.priv_sub1.id
  route_table_id = aws_route_table.private_RT1.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.priv_sub2.id
  route_table_id = aws_route_table.private_RT2.id
}

# Creates Security group
  resource "aws_security_group" "ssh_web" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.terraform_lab.id

  ingress {
    description      = "ssh from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "web from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web & ssh"
  }
}

#Creates a network interface1
  resource "aws_network_interface" "nic1" {
  subnet_id       = aws_subnet.pub_sub1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.ssh_web.id]
}

#Creates a network interface2
  resource "aws_network_interface" "nic2" {
  subnet_id       = aws_subnet.priv_sub1.id
  private_ips     = ["10.0.3.50"]
  security_groups = [aws_security_group.ssh_web.id]
}

#Creates a network interface3
  resource "aws_network_interface" "nic3" {
  subnet_id       = aws_subnet.priv_sub2.id
  private_ips     = ["10.0.4.50"]
  security_groups = [aws_security_group.ssh_web.id]
}


#create ec2 instance 1
  resource "aws_instance" "web1" {
  ami           = "ami-0b6937ac543fe96d7"
  availability_zone = "ca-central-1a"
  instance_type = "t2.micro"
  key_name = "Terraform"

  network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.nic1.id
  }

  tags = {
    Name = "Terraform_1"
  }

}
#create ec2 instance 2
  resource "aws_instance" "web2" {
  ami           = "ami-0b6937ac543fe96d7"
  availability_zone = "ca-central-1a"
  instance_type = "t2.micro"
  key_name = "Terraform"

  network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.nic2.id
  }

  tags = {
    Name = "Terraform_2"
  }
}
#create ec2 instance 3
  resource "aws_instance" "web3" {
  ami           = "ami-0b6937ac543fe96d7"
  availability_zone = "ca-central-1b"
  instance_type = "t2.micro"
  key_name = "Terraform"

  network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.nic3.id
  }

  tags = {
    Name = "Terraform_3"
  }
}




