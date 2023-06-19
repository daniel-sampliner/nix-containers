# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ perSystem, ... }@top:
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
        coreutils = pkgs.callPackage ../ctrs/coreutils { inherit created; };
        komga = pkgs.callPackage ../ctrs/komga { inherit created; };
        qbittorrent-nox = pkgs.callPackage ../ctrs/qbittorrent-nox { inherit created; };
        socat = pkgs.callPackage ../ctrs/socat { inherit created; };
        pbr = pkgs.callPackage ../ctrs/pbr { inherit created; };
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
