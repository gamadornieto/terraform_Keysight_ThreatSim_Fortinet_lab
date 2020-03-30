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

variable "environment_tag" {
  default = "Splunk"
}

variable "owner_tag" {}
variable "tag_type" {
  default = "tag"
}

variable "APIbaseURL" {}
variable "organizationID" {}

variable "num_private_agents" {
  default = 0
}

variable "num_public_agents" {
  default = 0
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


##################################################################################
# Declare User Data templates
##################################################################################

data "template_file" "userdata_boostrap_splunk" {
  template = "${file("../templates/bootstrap_splunk.sh")}"
}

#data "template_file" "userdata_install_siem_agent" {
#template = "${file("../templates/install-siem-agent.sh")}"
#}



##################################################################################
# RESOURCES VMs
##################################################################################


resource "aws_instance" "siem_agent" {
  subnet_id = "${aws_subnet.public_subnet1.id}"

  ami             = "ami-0fc61db8544a617ed"
  instance_type = "t2.micro"
  key_name        = "${var.key_name}"

  vpc_security_group_ids = ["${aws_security_group.gustavo-public-default-sg.id}"]

  connection {
    user        = "ec2-user"
    host = "${self.public_ip}"
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "file" {
    source = "../templates/install-siem-agent.sh"
    destination = "/home/ec2-user/install-siem-agent.sh"
  }

  provisioner "file" {
    source = "../../terraform_credentials/tas_token"
    destination = "/tmp/token"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install docker -y",
      "sudo service docker start",
      "sudo chmod +x /home/ec2-user/install-siem-agent.sh",
      "sudo mkdir /root/.threatsim",
      "sudo mv /tmp/token /root/.threatsim/token ",
      "sudo /home/ec2-user/install-siem-agent.sh",
    ]
  }

  tags = {
    Name = "${var.owner_tag}-${var.environment_tag}-siem-agent"
    name = "${var.owner_tag}-${var.environment_tag}-siem-agent"
    Owner = "${var.owner_tag}"
  }
}


resource "aws_eip" "splunk_public_eip" {
  instance = "${aws_instance.splunk.id}"
  vpc      = true
}

resource "aws_instance" "splunk" {
  subnet_id = "${aws_subnet.public_subnet1.id}"

  # This is Ubuntu 18.04
  ami             = "ami-05931c30a2581ea20"
  instance_type = "t2.xlarge"

  root_block_device {
   volume_size = "20"
   volume_type = "standard"
 }

  key_name        = "${var.key_name}"

  vpc_security_group_ids = ["${aws_security_group.gustavo-public-splunk-sg.id}"]

  connection {
    user        = "ubuntu"
    host = "${self.public_ip}"
    private_key = "${file(var.private_key_path)}"
  }

  provisioner "file" {
    source = "../templates/user-seed.conf"
    destination = "/home/ubuntu/user-seed.conf"
  }

 user_data = "${data.template_file.userdata_boostrap_splunk.rendered}"

  tags = {
    Name = "${var.owner_tag}-${var.environment_tag}-splunk"
    name = "${var.owner_tag}-${var.environment_tag}-splunk"
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

resource "aws_security_group" "gustavo-public-splunk-sg" {
  name        = "${var.owner_tag}-${var.environment_tag}_public_splunk_sg"
  vpc_id      = "${aws_vpc.main.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }
  ingress {
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.siem_agent.public_ip}/32"]
  }
  #Following should be only for IPs of agents
  ingress {
    from_port   = 5514
    to_port     = 5514
    protocol    = "tcp"
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
    Name = "${var.owner_tag}-${var.environment_tag}_public_splunk_sg"
    Environment = "${var.environment_tag}"
  }
}
