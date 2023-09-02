# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ inputs, perSystem, ... }@top:
let
  lmd = top.self.lastModifiedDate;
  year = builtins.substring 0 4 lmd;
  month = builtins.substring 4 2 lmd;
  day = builtins.substring 6 2 lmd;
  hour = builtins.substring 8 2 lmd;
  minute = builtins.substring 10 2 lmd;
  second = builtins.substring 12 2 lmd;
  created = "${year}-${month}-${day}T${hour}:${minute}:${second}Z";
in
{
  perSystem = { pkgs, ... }:
    let
      ctrs = {
        caddy = pkgs.callPackage ../ctrs/caddy { inherit created; };
        cfdyndns = pkgs.callPackage ../ctrs/cfdyndns { inherit created; };
        coreutils = pkgs.callPackage ../ctrs/coreutils { inherit created; };
        komga = pkgs.callPackage ../ctrs/komga { inherit created; };
        veloren-healthcheck = pkgs.callPackage ../ctrs/veloren-healthcheck { inherit created; };
        pbr = pkgs.callPackage ../ctrs/pbr { inherit created; };
        qbittorrent-nox = pkgs.callPackage ../ctrs/qbittorrent-nox { inherit created; };
        socat = pkgs.callPackage ../ctrs/socat { inherit created; };
        vrising = pkgs.callPackage ../ctrs/vrising { inherit created; };

        cetusguard = pkgs.callPackage ../ctrs/cetusguard { inherit created; src = inputs.cetusguard; };
      };

      manifest = (pkgs.writeText "manifest" (builtins.toJSON
        (builtins.mapAttrs
          (_: v: { name = v.imageName; tag = v.imageTag; })
          ctrs))).overrideAttrs (_: { allowSubstitutes = true; });
    in
    {
      packages = ctrs // { inherit manifest; };
    };
}
