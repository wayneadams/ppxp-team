# Create the project (tenant)
#
# Add admin and releng-ci users to project
#   - roles should include admin and member
# ensure keypair is available to releng-ci user
#
# apply this script:
#    terraform apply -state=mars.tfstate
#
# update env.yml file
#   - internal network id
#   - ops manager ip address
#   - ha_proxy floating ip
#   - tcp_router floating ip

variable "tenant" {
  default = "mars"
}

variable "octet"
{
  default = "116"
}

variable "route53_zone" {
  default = "Z3G1T8EC1TPEPX"
}

variable "access_key" {}
variable "secret_key" {}
variable "password" {}

# Configure the OpenStack Provider
provider "openstack" {
  user_name = "releng-ci"
  tenant_name = "${var.tenant}"
  password = "${var.password}"
  auth_url = "http://10.85.38.2:5000/v2.0"
}

resource "openstack_compute_secgroup_v2" "secgroup_products" {
  name = "${var.tenant}-products"
  description = "Products Security Group"
  region = "RegionOne"

  rule {
    ip_protocol = "tcp"
    from_port = "80"
    to_port = "80"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port = "443"
    to_port = "443"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port = "4443"
    to_port = "4443"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port = "2222"
    to_port = "2222"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port = "1"
    to_port = "65535"
    self = true
  }

  rule {
    ip_protocol = "udp"
    from_port = "1"
    to_port = "65535"
    self = true
  }

  rule {
    ip_protocol = "tcp"
    from_port = "1024"
    to_port = "1123"
    cidr = "0.0.0.0/0"
  }
}

resource "openstack_compute_secgroup_v2" "secgroup_ops_manager" {
  name = "${var.tenant}-ops-manager"
  description = "Ops Manager Security Group"
  region = "RegionOne"

  rule {
    ip_protocol = "tcp"
    from_port = "22"
    to_port = "22"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port = "80"
    to_port = "80"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port = "443"
    to_port = "443"
    cidr = "0.0.0.0/0"
  }

  rule {
    ip_protocol = "tcp"
    from_port = "1"
    to_port = "65535"
    from_group_id = "${openstack_compute_secgroup_v2.secgroup_products.id}"
  }

}

resource "openstack_networking_network_v2" "internal_net" {
  name = "${var.tenant}_net"
  region = "RegionOne"
  admin_state_up = "true"

}

resource "openstack_networking_subnet_v2" "internal_subnet" {
  region = "RegionOne"
  network_id = "${openstack_networking_network_v2.internal_net.id}"
  cidr = "192.168.${var.octet}.0/24"
  ip_version = 4
  allocation_pools = {
    start = "192.168.${var.octet}.2"
    end = "192.168.${var.octet}.254"
  }
  enable_dhcp = true
  dns_nameservers = [
    "10.87.8.10",
    "10.87.8.11"]

}

resource "openstack_networking_router_v2" "internal_router" {
  region = "RegionOne"
  name = "${var.tenant}-router"
  external_gateway = "5b2a49cc-acef-4e4f-b464-8b7687fab914"
  admin_state_up = "true"

}

resource "openstack_networking_router_interface_v2" "internal_interface" {
  region = "RegionOne"
  router_id = "${openstack_networking_router_v2.internal_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.internal_subnet.id}"
}

resource "openstack_networking_floatingip_v2" "floatip_1" {
  region = "RegionOne"
  pool = "net04_ext"
}
resource "openstack_networking_floatingip_v2" "floatip_2" {
  region = "RegionOne"
  pool = "net04_ext"
}
resource "openstack_networking_floatingip_v2" "floatip_3" {
  region = "RegionOne"
  pool = "net04_ext"
}

output "internal_network_id"
{
  value = "${openstack_networking_network_v2.internal_net.id}"
}

output "ops_man_floating_ip"
{
  value = "${openstack_networking_floatingip_v2.floatip_1.address}"
}
output "ha_proxy_floating_ip"
{
  value = "${openstack_networking_floatingip_v2.floatip_2.address}"
}
output "tcp_router_floating_ip"
{
  value = "${openstack_networking_floatingip_v2.floatip_3.address}"
}

provider "aws" {
  alias = "aws"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "us-west-1"
}

resource "aws_route53_record" "pcf" {
  provider = "aws.aws"
  zone_id = "${var.route53_zone}"
  name = "pcf"
  type = "A"
  ttl = "60"
  records = [
    "${openstack_networking_floatingip_v2.floatip_1.address}"]
}
resource "aws_route53_record" "wildcard" {
  provider = "aws.aws"
  zone_id = "${var.route53_zone}"
  name = "*"
  type = "A"
  ttl = "60"
  records = [
    "${openstack_networking_floatingip_v2.floatip_2.address}"]
}
resource "aws_route53_record" "tcp" {
  provider = "aws.aws"
  zone_id = "${var.route53_zone}"
  name = "tcp"
  type = "A"
  ttl = "60"
  records = [
    "${openstack_networking_floatingip_v2.floatip_3.address}"]
}
