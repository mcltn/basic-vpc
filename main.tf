data "ibm_is_ssh_key" "sshkey1" {
  name = "${var.ssh_key_name}"
}

resource "ibm_is_vpc" "vpc1" {
  name = "${var.vpc_name}"
  address_prefix_management = "auto"
}

resource "ibm_is_vpc_address_prefix" "vpc-ap1" {
  name = "vpc-ap1"
  zone = "${var.zone1}"
  vpc  = "${ibm_is_vpc.vpc1.id}"
  cidr = "${var.zone1_cidr}"
}

resource "ibm_is_subnet" "sn1" {
  name            = "subnet1"
  vpc             = "${ibm_is_vpc.vpc1.id}"
  zone            = "${var.zone1}"
  ipv4_cidr_block = "${var.zone1_cidr}"
  depends_on      = ["ibm_is_vpc_address_prefix.vpc-ap1"]
}

resource "ibm_is_instance" "app" {
  count = "${var.instance_count}"
  name    = "app-${count.index+1}"
  image   = "${var.image}"
  profile = "${var.profile}"

  primary_network_interface = {
    subnet = "${ibm_is_subnet.sn1.id}"
  }
  vpc  = "${ibm_is_vpc.vpc1.id}"
  zone = "${var.zone1}"
  keys = ["${data.ibm_is_ssh_key.sshkey1.id}"]
  user_data = "${data.local_file.app-config.content}"
  #user_data = "${data.template_cloudinit_config.cloud-init-apptier.rendered}"
}

resource "ibm_is_instance" "db" {
  count = "${var.instance_count}"
  name    = "db-${count.index+1}"
  image   = "${var.image}"
  profile = "${var.profile}"

  primary_network_interface = {
    subnet = "${ibm_is_subnet.sn1.id}"
  }
  vpc  = "${ibm_is_vpc.vpc1.id}"
  zone = "${var.zone1}"
  keys = ["${data.ibm_is_ssh_key.sshkey1.id}"]
  #user_data = "${data.template_cloudinit_config.cloud-init-dbtier.rendered}"
}

resource "ibm_is_floating_ip" "fip-app" {
  count = "${ibm_is_instance.app.count}"
  name = "fip-app-${count.index}"
  target = "${element(ibm_is_instance.app.*.primary_network_interface.0.id, count.index)}"
}

resource "ibm_is_floating_ip" "fip-db" {
  count = "${ibm_is_instance.db.count}"
  name = "fip-db-${count.index}"
  target = "${element(ibm_is_instance.db.*.primary_network_interface.0.id, count.index)}"
}

resource "ibm_is_security_group_rule" "sg1_tcp_rule_22" {
  #depends_on = ["ibm_is_floating_ip.floatingip1"]
  group     = "${ibm_is_vpc.vpc1.default_security_group}"
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp = {
    port_min = "22"
    port_max = "22"
  }
}

resource "ibm_is_security_group_rule" "sg1_tcp_rule_80" {
  group     = "${ibm_is_vpc.vpc1.default_security_group}"
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp = {
    port_min = "80"
    port_max = "80"
  }
}


data "local_file" "app-config" {
  filename = "${path.module}/cloud-init.txt"
}

output "fip-app" {
    value = "${ibm_is_floating_ip.fip-app.*.address}"
}
output "fip-db" {
    value = "${ibm_is_floating_ip.fip-db.*.address}"
}
