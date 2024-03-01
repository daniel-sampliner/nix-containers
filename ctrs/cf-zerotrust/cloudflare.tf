# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

variable "cloudflare_account_id" { type = string }

resource "cloudflare_access_group" "house" {
  account_id = var.cloudflare_account_id

  name = "house"

  include {
    ip = [
      local.ip4,
      local.ip6
    ]
  }
}

output "access_group_id" { value = cloudflare_access_group.house.id }
