provider "aws" {
    region = "ap-southeast-1"
}

data "aws_availability_zones" "available" {}

data "template_file" "user_data_nat" {
  template = "${file("webserver.sh")}"

  vars {
    server_port = "${var.server_port}"
  }
}

data "template_file" "user_data_vpn" {
  template = "${file("vpn.sh")}"

  vars {
    local_subnet = "${aws_subnet.sn04.cidr_block}"
    remote_subnet = "${aws_subnet.sn02.cidr_block}"
    local_ipv4_priv = "${aws_network_interface.eni03.private_ips[0]}"
    local_ipv4_pub = "${aws_eip.eip02.public_ip}"
    remote_ipv4_pub = "${aws_vpn_connection.vpnc01.tunnel1_address}"
    vpn_psk = "${aws_vpn_connection.vpnc01.tunnel1_preshared_key}"
  }
}

variable "server_port" { default = 80 }

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

resource "aws_vpc" "vpc02" {
  cidr_block           = "10.11.0.0/16"
  enable_dns_hostnames = true

  tags {
    Name = "vpc02"
  }
}

resource "aws_internet_gateway" "igw01" {
  vpc_id = "${aws_vpc.vpc01.id}"

  tags {
    Name = "vpc01_igw"
  }
}

resource "aws_internet_gateway" "igw02" {
  vpc_id = "${aws_vpc.vpc02.id}"

  tags {
    Name = "vpc02_igw"
  }
}

resource "aws_subnet" "sn01" {
  vpc_id                  = "${aws_vpc.vpc01.id}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  cidr_block              = "10.10.0.0/24"
  map_public_ip_on_launch = true

  tags {
    Name = "vpc01_sn_public"
  }
}

resource "aws_subnet" "sn02" {
  vpc_id                  = "${aws_vpc.vpc01.id}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  cidr_block              = "10.10.1.0/24"
  map_public_ip_on_launch = false

  tags {
    Name = "vpc01_sn_private"
  }
}

resource "aws_subnet" "sn03" {
  vpc_id                  = "${aws_vpc.vpc02.id}"
  cidr_block              = "10.11.0.0/24"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  map_public_ip_on_launch = true

  tags {
    Name = "vpc02_sn_public"
  }
}

resource "aws_subnet" "sn04" {
  vpc_id                  = "${aws_vpc.vpc02.id}"
  cidr_block              = "10.11.1.0/24"
  availability_zone = "${data.aws_availability_zones.available.names[1]}"
  map_public_ip_on_launch = false

  tags {
    Name = "vpc02_sn_private"
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

resource "aws_network_interface" "eni03" {
  subnet_id = "${aws_subnet.sn03.id}"
  private_ips = ["10.11.0.6"]
  security_groups = ["${aws_security_group.allow_all_02.id}"]
  source_dest_check = false
}

resource "aws_network_interface" "eni04" {
  subnet_id = "${aws_subnet.sn04.id}"
  private_ips = ["10.11.1.6"]
  security_groups = ["${aws_security_group.allow_all_02.id}"]
  source_dest_check = false
}

resource "aws_eip" "eip01" {
  vpc      = true
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_eip" "eip02" {
  vpc      = true
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_eip_association" "eip_assoc_01" {
  network_interface_id   = "${aws_network_interface.eni01.id}"
  allocation_id = "${aws_eip.eip01.id}"
}

resource "aws_eip_association" "eip_assoc_02" {
  network_interface_id   = "${aws_network_interface.eni03.id}"
  allocation_id = "${aws_eip.eip02.id}"
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

resource "aws_route_table" "rtb03" {
  vpc_id = "${aws_vpc.vpc02.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw02.id}"
  }

  tags {
    Name = "aws_route_table"
  }
}
resource "aws_route_table" "rtb04" {
  vpc_id = "${aws_vpc.vpc02.id}"

  route {
    cidr_block = "0.0.0.0/0"
    network_interface_id = "${aws_network_interface.eni04.id}"
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

resource "aws_route_table_association" "a03" {
  subnet_id      = "${aws_subnet.sn03.id}"
  route_table_id = "${aws_route_table.rtb03.id}"
}

resource "aws_route_table_association" "a04" {
  subnet_id      = "${aws_subnet.sn04.id}"
  route_table_id = "${aws_route_table.rtb04.id}"
}

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

resource "aws_security_group" "allow_all_02" {
  name        = "allow_all_02"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = "${aws_vpc.vpc02.id}"

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

resource "aws_instance" "v1_node" {
    count = 2
    ami = "ami-82c9ecfe"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.sn02.id}"
    vpc_security_group_ids = ["${aws_security_group.allow_all_01.id}"]
    key_name = "${aws_key_pair.kp01.key_name}"
    user_data = "${data.template_file.user_data_nat.rendered}"

    tags {
        Name = "v1_node${count.index}"
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
    
    tags {
        Name = "vpn_node_01"
    }
    lifecycle {
        create_before_destroy = true
    }
}


resource "aws_instance" "v2_node" {
    count = 2
    ami = "ami-82c9ecfe"
    instance_type = "t2.micro"
    subnet_id = "${aws_subnet.sn04.id}"
    vpc_security_group_ids = ["${aws_security_group.allow_all_02.id}"]
    key_name = "${aws_key_pair.kp01.key_name}"
    user_data = "${data.template_file.user_data_nat.rendered}"

    tags {
        Name = "v2_node${count.index}"
    }
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_instance" "vpn_node_02" {
    ami = "ami-270f735b"
    instance_type = "t2.micro"
    network_interface = [
      { 
        device_index = 0
        network_interface_id = "${aws_network_interface.eni03.id}"
      },
      { 
        device_index = 1
        network_interface_id = "${aws_network_interface.eni04.id}"
      } 
    ]
    key_name = "${aws_key_pair.kp01.key_name}"
    user_data = "${data.template_file.user_data_vpn.rendered}"
    
    tags {
        Name = "vpn_node_02"
    }
    lifecycle {
        create_before_destroy = true
    }
}

# VPN SECTION
resource "aws_vpn_gateway" "vgw01" {
  vpc_id = "${aws_vpc.vpc01.id}"
}

resource "aws_customer_gateway" "cgw01" {
  bgp_asn    = 65001
  ip_address = "${aws_eip.eip02.public_ip}"
  type       = "ipsec.1"
}

resource "aws_vpn_connection" "vpnc01" {
  vpn_gateway_id      = "${aws_vpn_gateway.vgw01.id}"
  customer_gateway_id = "${aws_customer_gateway.cgw01.id}"
  type                = "ipsec.1"
  static_routes_only  = true
  tunnel1_preshared_key = "_aBc_DeFeD_cBa_1_2_3_2_1_"
}

# OUTPUTS
output "vpn_node_public_ips" {
    value = [ "${aws_instance.vpn_node_01.public_ip}", "${aws_instance.vpn_node_02.public_ip}" ]
}
output "node_private_ips" {
    value = [ "${aws_instance.v1_node.*.private_ip}", "${aws_instance.v2_node.*.private_ip}" ]
}