# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

variable "host_lookup" { type = string }

variable "ipv6_prefix" {
  type    = string
  default = "56"
}


data "dns_a_record_set" "host" { host = var.host_lookup }
data "dns_aaaa_record_set" "host" { host = var.host_lookup }

locals {
  ip4 = "${one(data.dns_a_record_set.host.addrs)}/32"

  ip6_base = cidrhost("${one(data.dns_aaaa_record_set.host.addrs)}/${var.ipv6_prefix}", 0)
  ip6      = "${local.ip6_base}/${var.ipv6_prefix}"
}

output "ip4" { value = local.ip4 }
output "ip6" { value = local.ip6 }
