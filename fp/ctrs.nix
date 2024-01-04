# SPDX-FileCopyrightText: 2023 - 2024 Daniel Sampliner <samplinerD@gmail.com>
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
  perSystem = { pkgs, system, ... }:
    let
      ctrs = {
        caddy = pkgs.callPackage ../ctrs/caddy { };
        cfdyndns = pkgs.callPackage ../ctrs/cfdyndns { };
        chrony = pkgs.callPackage ../ctrs/chrony { };
        coreutils = pkgs.callPackage ../ctrs/coreutils { };
        komga = pkgs.callPackage ../ctrs/komga { };
        pbr = pkgs.callPackage ../ctrs/pbr { };
        qbittorrent-nox = pkgs.callPackage ../ctrs/qbittorrent-nox { };
        socat = pkgs.callPackage ../ctrs/socat { };
        syncthing = pkgs.callPackage ../ctrs/syncthing { };
        veloren-healthcheck = pkgs.callPackage ../ctrs/veloren-healthcheck { };
        vrising = pkgs.callPackage ../ctrs/vrising { };
        wireguard = pkgs.callPackage ../ctrs/wireguard { };

        cetusguard = pkgs.callPackage ../ctrs/cetusguard { src = inputs.cetusguard; };
      };

      manifest = (pkgs.writeText "manifest" (builtins.toJSON
        (builtins.mapAttrs
          (_: v: { name = v.imageName; tag = v.imageTag; })
          ctrs))).overrideAttrs (_: { allowSubstitutes = true; });
    in
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          (final: prev:
            let inherit (final) lib; in {
              dockerTools = prev.dockerTools // {
                streamLayeredImage = args: lib.pipe args [
                  (a: a // {
                    inherit created;
                    maxLayers = a.maxLayers or 125;
                  })
                  prev.dockerTools.streamLayeredImage
                  (d: builtins.getAttr "overrideAttrs" d (old:
                    let
                      inherit (old) buildCommand;
                      streamScript = lib.pipe buildCommand [
                        (lib.splitString " ")
                        (l: builtins.elemAt l 1)
                      ];
                      patchedScript = final.runCommand "stream" { } ''
                        patch -o "$out" "${streamScript}" "${./layer-mtime.patch}"
                        chmod a+x "$out"
                      '';
                      newBuildCommand = builtins.replaceStrings
                        [ streamScript ]
                        [ "${patchedScript}" ]
                        buildCommand;
                    in
                    assert (lib.isStorePath streamScript);
                    { buildCommand = newBuildCommand; }
                  ))
                ];
              };
            })
        ];
      };

      packages = ctrs // { inherit manifest; };
    };
}
