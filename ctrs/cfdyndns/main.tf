# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

terraform {
  cloud {}
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

data "http" "ip" {
  url = "https://ipv4.icanhazip.com"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "status code invalid"
    }
  }
}


variable "zone" {
  type = string
}

variable "record" {
  type = string
}

data "cloudflare_zone" "main" {
  name = var.zone
}

resource "cloudflare_record" "main" {
  name    = var.record
  type    = "A"
  value   = chomp(data.http.ip.response_body)
  zone_id = data.cloudflare_zone.main.id

  proxied = false
  ttl     = 300
}
