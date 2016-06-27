variable "domain" {
  type = "string"
  default = "int.5pi.de"
}

variable "api_token" {
  type = "string"
}

variable "cluster_state" {
  type = "string"
  default = "existing"
  description = "Set this to 'new' for initial cluster creation"
}

variable "servers" {
  default = 3
}

variable "ip_int_prefix" {
  type = "string"
  default = "10.130"
}

variable "image" {
  type = "string"
  default = "18135790"
}

provider "digitalocean" {
  token = "${var.api_token}"
}

resource "digitalocean_ssh_key" "default" {
  name = "terraform"
  public_key = "${file("id_rsa.pub")}"
}

resource "digitalocean_droplet" "master" {
  count = "${var.servers}"
  name = "master${count.index}"
  image = "${var.image}"
  region = "ams3"
  size = "512mb"
  private_networking = true
  ssh_keys = [ "${digitalocean_ssh_key.default.id}" ]
  provisioner "file" {
      source = "configure.sh"
      destination = "/tmp/configure.sh"
  }
  provisioner "file" {
      source = "../config/master${count.index}/rsa_key.priv"
      destination = "/etc/tinc/default/rsa_key.priv"
  }
  provisioner "remote-exec" {
    inline = [
      "cat <<EOF > /etc/environment.tf",
      "DOMAIN=${var.domain}",
      "INDEX=${count.index}",
      "SERVERS=${var.servers}",
      "IP_INT_PREFIX=${var.ip_int_prefix}",
      "IP_PRIVATE=${self.ipv4_address_private}",
      "STATE=${var.cluster_state}",
      "TORUS_SIZE=20GiB",
      "EOF",
      "chmod a+x /tmp/configure.sh",
      "exec /tmp/configure.sh"
    ]
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "digitalocean_record" "master_a" {
  count = "${var.servers}"
  domain = "${var.domain}"
  type = "A"
  name = "master${count.index}"
  value = "${element(digitalocean_droplet.master.*.ipv4_address_private, count.index)}"
}
