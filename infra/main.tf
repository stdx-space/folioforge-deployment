terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.46.3"
    }
  }
}

provider "proxmox" {
  ssh {
    agent = false
    node {
      name    = "pve"
      address = "pve.stdx.space"
    }
  }
}

locals {
  node            = "pve"
  network         = "10.101.0.0/16"
  ips             = ["10.101.101.1"]
  os_template_id  = "local:iso/flatcar_production_qemu_image.img"
  cluster_size    = 1
  authorized_keys = split("\n", data.http.ssh_pubkeys.response_body)
}

data "http" "ssh_pubkeys" {
  url = "https://github.com/STommydx.keys"
}

# module "pki" {
#   source              = "git::https://gitlab.com/narwhl/wip/blueprint.git//modules/pki"
#   root_ca_common_name = "STDXSPACE"
#   root_ca_org_name    = "Hashicorp"
#   root_ca_org_unit    = "Development"
#   extra_server_certificates = [
#     {
#       san_dns_names    = ["nomad.local"]
#       san_ip_addresses = local.ips
#     }
#   ]
# }

module "consul" {
  source          = "git::https://gitlab.com/narwhl/wip/blueprint.git//modules/consul"
  datacenter_name = "dc1"
  role            = "server"
}

module "nomad" {
  source          = "git::https://gitlab.com/narwhl/wip/blueprint.git//modules/nomad"
  datacenter_name = "dc1"
  role            = "server"
}

module "flatcar" {
  source  = "git::https://gitlab.com/narwhl/wip/blueprint.git//modules/flatcar"
  name    = "folioforge"
  network = local.network
  # ca_certs = [
  #   module.pki.keychain.root_ca_cert,
  #   module.pki.keychain.intermediate_ca_cert
  # ]
  ip_address = local.ips[0]
  gateway_ip = cidrhost(local.network, 1)
  substrates = [
    module.consul.manifest,
    module.nomad.manifest
  ]
  ssh_authorized_keys = local.authorized_keys
}

module "proxmox" {
  source              = "git::https://gitlab.com/narwhl/wip/blueprint.git//modules/proxmox"
  name                = "folioforge"
  node                = local.node
  vcpus               = 2
  memory              = 4096
  storage_pool        = "local-lvm"
  disk_size           = 48
  os_template_id      = local.os_template_id
  provisioning_config = module.flatcar.config
  networks = [
    {
      id = "vmbr1"
    }
  ]
}

