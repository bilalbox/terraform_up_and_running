provider "aws" {
    region = "ap-southeast-1"
}

variable "server_port" {
    description = "The port that the server will listen on for HTTP requests"
    default = 80
}

resource "aws_key_pair" "kp01" {
  key_name   = "kp01"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCyCKTwrNMNUjVMKKbcCnMolBUx1l2rUM4g/1yYWszSfiSYrgHLt1ia4V4xyo5kIC9rBru9ylWYq0tC3RVNnuIQBQIpkft9FMVgpMGNPi8Ov7ruDwz43Sy0Wk/XrX19slRzoVkGWE+NyrFkgDCSBXdVrpkDVkH2QQBafB+a2WflxepjH0p8YiqsSQi4Kr3sgyrZnYJ/V3Qt0UB+jvmWYoC8HE3PQNMPbElqupy/DJ24Vs9tGhwsV1AAYetU4AN5ExPueRaYkw8ysPL5ck8NPyI7g54MHnYr3UKEpp0+uHOSstnuN4st80lMsOaN3gAc9RMC5JzEWPPpuNEtvyonulVt bilalbox"
}

resource "aws_vpc" "vpc01" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true

  tags {
    Name = "vpc01"
  }
}

resource "aws_internet_gateway" "igw01" {
  vpc_id = "${aws_vpc.vpc01.id}"

  tags {
    Name = "vpc01_igw"
  }
}

resource "aws_subnet" "sn01" {
  vpc_id                  = "${aws_vpc.vpc01.id}"
  cidr_block              = "10.10.0.0/24"
  map_public_ip_on_launch = true

  tags {
    Name = "vpc01_sn_public"
  }
}

resource "aws_subnet" "sn02" {
  vpc_id                  = "${aws_vpc.vpc01.id}"
  cidr_block              = "10.10.1.0/24"
  map_public_ip_on_launch = false

  tags {
    Name = "vpc01_sn_private"
  }
}

resource "aws_network_interface" "eni01" {
  subnet_id = "${aws_subnet.sn01.id}"
  private_ips = ["10.10.0.6"]
  security_groups = ["${aws_security_group.allow_all_01.id}"]
  source_dest_check = false
}

resource "aws_network_interface" "eni02" {
  subnet_id = "${aws_subnet.sn02.id}"
  private_ips = ["10.10.1.6"]
  security_groups = ["${aws_security_group.allow_all_01.id}"]
  source_dest_check = false
}

resource "aws_eip" "eip01" {
  vpc      = true
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_eip_association" "eip_assoc_01" {
  network_interface_id   = "${aws_network_interface.eni01.id}"
  allocation_id = "${aws_eip.eip01.id}"
}

resource "aws_route_table" "rtb01" {
  vpc_id = "${aws_vpc.vpc01.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw01.id}"
  }

  tags {
    Name = "aws_route_table"
  }
}
resource "aws_route_table" "rtb02" {
  vpc_id = "${aws_vpc.vpc01.id}"

  route {
    cidr_block = "0.0.0.0/0"
    network_interface_id = "${aws_network_interface.eni02.id}"
  }

  tags {
    Name = "aws_route_table"
  }
}

resource "aws_route_table_association" "a01" {
  subnet_id      = "${aws_subnet.sn01.id}"
  route_table_id = "${aws_route_table.rtb01.id}"
}

resource "aws_route_table_association" "a02" {
  subnet_id      = "${aws_subnet.sn02.id}"
  route_table_id = "${aws_route_table.rtb02.id}"
}

# resource "aws_vpn_gateway" "vgw01" {
#   vpc_id = "${aws_vpc.vpc01.id}"
# }

# resource "aws_customer_gateway" "cgw01" {
#   bgp_asn    = 65001
#   ip_address = "${aws_instance.vpn_node_02.public_ip}"
#   type       = "ipsec.1"
# }

# resource "aws_vpn_connection" "vpnc01" {
#   vpn_gateway_id      = "${aws_vpn_gateway.vgw01.id}"
#   customer_gateway_id = "${aws_customer_gateway.cgw01.id}"
#   type                = "ipsec.1"
#   static_routes_only  = true
# }

resource "aws_security_group" "allow_all_01" {
  name        = "allow_all_01"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = "${aws_vpc.vpc01.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "node" {
    count = 2
    ami = "ami-82c9ecfe"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.sn02.id}"
    vpc_security_group_ids = ["${aws_security_group.allow_all_01.id}"]
    key_name = "${aws_key_pair.kp01.key_name}"
    user_data = <<-EOF
                #!/bin/bash
                export HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/local-hostname)
                export PRIVATE_IPV4=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
                echo Host: $HOSTNAME, IP Address: $PRIVATE_IPV4 > index.html
                nohup busybox httpd -f -p "${var.server_port}" &
                EOF

    tags {
        Name = "node${count.index}"
    }
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_instance" "vpn_node_01" {
    ami = "ami-270f735b"
    instance_type = "t2.micro"
    network_interface = [
      { 
        device_index = 0
        network_interface_id = "${aws_network_interface.eni01.id}"
      },
      { 
        device_index = 1
        network_interface_id = "${aws_network_interface.eni02.id}"
      } 
    ]
    key_name = "${aws_key_pair.kp01.key_name}"
    #user_data = "${file("nat.sh")}"
    
    tags {
        Name = "vpn_node_01"
    }
    lifecycle {
        create_before_destroy = true
    }
}

# OUTPUTS
output "vpn_node_public_ips" {
    value = "${aws_instance.vpn_node_01.public_ip}"
}
output "node_private_ips" {
    value = "${aws_instance.node.*.private_ip}"
}