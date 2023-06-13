# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ inputs, perSystem, ... }: {
  imports = builtins.catAttrs "flakeModule" (builtins.attrValues {
    inherit (inputs)
      devshell
      pre-commit-hooks-nix
      ;
  });

  perSystem = { config, lib, pkgs, ... }:
    let
      runtimePkgs = builtins.attrValues {
        inherit (pkgs)
          pigz
          redo-apenwarr
          skopeo
          ;
      };
    in
    {
      devshells.default.devshell = {
        motd = "";
        name = "nix-containers";

        packages =
          let
            enabledPCHooks = lib.filterAttrs (_: v: v.enable)
              config.pre-commit.settings.hooks;

            pcPkgs = [ config.pre-commit.settings.package ]
              ++ lib.attrVals
              (builtins.attrNames enabledPCHooks)
              config.pre-commit.settings.tools
            ;
          in
          pcPkgs ++ runtimePkgs;

        startup.pre-commit.text = config.pre-commit.installationScript;
      };

      devshells.ci.devshell = {
        motd = "";
        name = "nix-containers CI";

        packages = runtimePkgs;
      };

      pre-commit.settings =
        let
          inherit (pkgs.python3.pkgs) pre-commit-hooks;
        in
        {
          hooks = {
            commitizen.enable = true;
            deadnix.enable = true;
            editorconfig-checker.enable = true;
            nixpkgs-fmt.enable = true;
            statix.enable = true;
            taplo.enable = true;

            end-of-file-fixer = {
              enable = true;
              name = "fix end of files";
              entry = "${pre-commit-hooks}/bin/end-of-file-fixer";
              types = [ "text" ];
            };

            reuse = {
              enable = true;
              name = "REUSE license compliance";
              entry = "${pkgs.reuse}/bin/reuse lint";
              pass_filenames = false;
            };
          };

          tools = {
            inherit (pkgs)
              reuse
              taplo
              ;

            end-of-file-fixer = pre-commit-hooks;
          };
        };
    };
}
