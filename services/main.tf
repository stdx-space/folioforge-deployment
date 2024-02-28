terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.19.0"
    }
  }
}

data "cloudflare_accounts" "tommy_li" {
  name = "Tommy Li"
}

data "cloudflare_zone" "stdx_space" {
  name = "stdx.space"
}

module "ingress" {
  source                = "git::https://gitlab.com/narwhl/wip/blueprint.git//modules/nomad-ingress"
  dns_zone_name         = "stdx.space"
  cloudflare_account_id = data.cloudflare_accounts.tommy_li.accounts[0].id
  acme_email            = "cloud@stdx.space"
  datacenter_name       = "dc1"
  traefik_version       = "latest"
  cloudflared_version   = "latest"
}

resource "cloudflare_record" "api" {
  zone_id = data.cloudflare_zone.stdx_space.id
  name    = "folioforge-api"
  type    = "CNAME"
  value   = module.ingress.cloudflare_tunnel_domain
  proxied = true
}

module "temporal" {
  source                = "git::https://gitlab.com/narwhl/wip/blueprint.git//modules/nomad-temporal?ref=feat%2Fnomad-temporal"
  datacenter_name       = "dc1"
  elasticsearch_version = "7.16.2"
  postgres_version      = "13"
  temporal_version      = "1.22.4"
  temporal_ui_version   = "2.22.3"
}
