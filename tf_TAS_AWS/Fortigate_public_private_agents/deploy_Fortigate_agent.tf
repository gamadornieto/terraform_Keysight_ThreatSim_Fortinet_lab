##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}
variable "aws_session_token" {
  default = ""
}
variable "private_key_path" {}
variable "key_name" {}
variable "iam_role" {}

variable "environment_tag" {
  default = "my-Fortigate"
}

variable "owner_tag" {}
variable "tag_type" {
  default = "db"
}

variable "APIbaseURL" {}
variable "organizationID" {}

variable "num_private_agents" {
  default = 1
}

variable "num_public_agents" {
  default = 1
}

variable "my_aws_region" {
  default = "us-east-1"
}

##################################################################################
# PROVIDERS
##################################################################################


provider "aws" {
  access_key = "${var.aws_access_key_id}"
  secret_key = "${var.aws_secret_access_key}"
  token  = "${var.aws_session_token}"
  region     = "${var.my_aws_region}"
}


##################################################################################
# Mappings
##################################################################################


variable "region_Linux2AMI" {
  type = "map"
default = {
    us-east-1 = "ami-009d6802948d06e52"
  }
}


##################################################################################
# VPC
##################################################################################

resource "aws_vpc" "main" {
  cidr_block       = "172.30.0.0/16"
  enable_dns_support = "true"
  enable_dns_hostnames = "true"
  tags = {
    Name = "${var.owner_tag}-${var.environment_tag}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
  tags = {
    Name = "${var.owner_tag}-${var.environment_tag}"
  }
}

resource "aws_subnet" "public_subnet1" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "172.30.0.0/24"
  availability_zone= "us-east-1a"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "${var.owner_tag}-${var.environment_tag}-public_subnet1"
  }
}

resource "aws_subnet" "private_subnet1" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "172.30.1.0/24"
  availability_zone= "us-east-1a"

  tags = {
    Name = "${var.owner_tag}-${var.environment_tag}-private_subnet1"
  }
}

resource "aws_route_table" "public_rt" {
 vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
  tags = {
    Name = "${var.owner_tag}-${var.environment_tag}-public_rt"
  }
}

resource "aws_route_table_association" "public_rt" {
	subnet_id = "${aws_subnet.public_subnet1.id}"
	route_table_id = "${aws_route_table.public_rt.id}"
}

resource "aws_route_table" "private_rt" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    network_interface_id  = "${aws_network_interface.fortigate-eth1.id}"
  }
  tags = {
    Name = "${var.owner_tag}-${var.environment_tag}-private_rt"
  }
}

resource "aws_route_table_association" "private_rt" {
	subnet_id = "${aws_subnet.private_subnet1.id}"
	route_table_id = "${aws_route_table.private_rt.id}"
}


##################################################################################
# Declare User Data templates
##################################################################################


data "template_file" "userdata_ami_agent" {
  template = "${file("../templates/ami_agent.sh")}"
  vars = {
    APIbaseURL = "${var.APIbaseURL}"
    organizationID = "${var.organizationID}"
  }
}

data "template_file" "userdata_boostrap_vm" {
  template = "${file("../templates/bootstrap_vm.sh")}"
}

##################################################################################
# RESOURCES VMs
##################################################################################


resource "aws_instance" "public_agent" {
  count = "${var.num_public_agents}"

  subnet_id = "${aws_subnet.public_subnet1.id}"

  ami             = "${var.region_Linux2AMI["${var.my_aws_region}"]}"
  instance_type = "t3.micro"
  key_name        = "${var.key_name}"

  vpc_security_group_ids = ["${aws_security_group.gustavo-public-default-sg.id}"]

  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  user_data = "${data.template_file.userdata_boostrap_vm.rendered}  ${data.template_file.userdata_ami_agent.rendered} /bin/bash /home/ec2-user/agent-init.run -- -n ${var.owner_tag}-${var.environment_tag}-TAS-public-agent${count.index} "

  tags = {
    Name = "${var.owner_tag}-${var.environment_tag}-TAS-public-agent${count.index}"
    name = "${var.owner_tag}-${var.environment_tag}-TAS-public-agent${count.index}"
    organizationID = "${var.organizationID}"
    Environment = "${var.environment_tag}"
    APIbaseURL = "${var.APIbaseURL}"
    Owner = "${var.owner_tag}"
  }
}

resource "aws_instance" "private_agent" {
  count = "${var.num_private_agents}"

  subnet_id = "${aws_subnet.private_subnet1.id}"

  ami             = "${var.region_Linux2AMI["${var.my_aws_region}"]}"
  instance_type = "t3.micro"
  key_name        = "${var.key_name}"
  #key_name        = "${var.region_key["${var.my_aws_region}"]}"

  vpc_security_group_ids = ["${aws_security_group.gustavo-private-default-sg.id}"]

  connection {
    user        = "ec2-user"
    private_key = "${file(var.private_key_path)}"
  }

  user_data = "${data.template_file.userdata_boostrap_vm.rendered}  ${data.template_file.userdata_ami_agent.rendered} /bin/bash /home/ec2-user/agent-init.run -- -n ${var.owner_tag}-${var.environment_tag}-TAS-private-agent${count.index} "

  tags = {
    Name = "${var.owner_tag}-${var.environment_tag}-TAS-private-agent${count.index}"
    name = "${var.owner_tag}-${var.environment_tag}-TAS-private-agent${count.index}"
    organizationID = "${var.organizationID}"
    Environment = "${var.environment_tag}"
    APIbaseURL = "${var.APIbaseURL}"
    Owner = "${var.owner_tag}"
  }
}

resource "aws_eip" "fortigate_public_eip" {
  network_interface = "${aws_network_interface.fortigate-eth0.id}"
  vpc      = true
}

resource "aws_network_interface" "fortigate-eth0" {
  subnet_id   = "${aws_subnet.public_subnet1.id}"
  source_dest_check = false
  security_groups = ["${aws_security_group.gustavo-fortigate-sg.id}"]
  tags = {
    Name = "${var.owner_tag}--${var.environment_tag}-Fortigate-eth0"
  }
}

resource "aws_network_interface" "fortigate-eth1" {
  subnet_id   = "${aws_subnet.private_subnet1.id}"
  source_dest_check = false
  security_groups = ["${aws_security_group.gustavo-fortigate-sg.id}"]
  tags = {
    Name = "${var.owner_tag}--${var.environment_tag}-Fortigate-eth1"
  }
}

resource "aws_instance" "fortigate" {

 network_interface {
   network_interface_id = "${aws_network_interface.fortigate-eth0.id}"
   device_index         = 0
 }
 network_interface {
   network_interface_id = "${aws_network_interface.fortigate-eth1.id}"
   device_index         = 1
 }

  ami             = "ami-0b3a07ff01ef9d97b"
  instance_type = "t2.small"
  key_name        = "${var.key_name}"
  #key_name        = "${var.region_key["${var.my_aws_region}"]}"

  connection {
    user        = "admin"
    private_key = "${file(var.private_key_path)}"
  }

  tags = {
    Name = "${var.owner_tag}-${var.environment_tag}-Fortigate"
    organizationID = "${var.organizationID}"
    Environment = "${var.environment_tag}"
    Owner = "${var.owner_tag}"
  }
}


##
# SECURITY GROUPS #
##

# Learn our public IP address
data "http" "myip" {
   url = "http://icanhazip.com"
}


# default security group
resource "aws_security_group" "gustavo-private-default-sg" {
  name        = "gustavo_private_default_sg"
  vpc_id      = "${aws_vpc.main.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
     from_port = 0
     to_port = 0
     protocol = "-1"
     cidr_blocks = ["0.0.0.0/0"]
   }
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow all egress traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.owner_tag}-${var.environment_tag}-private-default-sg"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_security_group" "gustavo-public-default-sg" {
  name        = "${var.owner_tag}-${var.environment_tag}_public_default_sg"
  vpc_id      = "${aws_vpc.main.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }
  # Allow all egress traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.owner_tag}-${var.environment_tag}_public_default_sg"
    Environment = "${var.environment_tag}"
  }
}

resource "aws_security_group" "gustavo-fortigate-sg" {
  name        = "gustavo_fortigate_sg"
  vpc_id      = "${aws_vpc.main.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }
  ingress {
    from_port   = 541
    to_port     = 541
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
     from_port = 0
     to_port = 0
     protocol = "-1"
     cidr_blocks = ["0.0.0.0/0"]
   }
  # Allow all egress traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.owner_tag}-${var.environment_tag}-Fortigate-sg"
    Environment = "${var.environment_tag}"
  }
}
