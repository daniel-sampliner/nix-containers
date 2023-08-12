# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{
  description = "nix containers";

  nixConfig = {
    extra-substituters = "https://veloren-nix.cachix.org";
    extra-trusted-public-keys = "veloren-nix.cachix.org-1:zokfKJqVsNV6kI/oJdLF6TYBdNPYGSb+diMVQPn/5Rc=";
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils/v1.0.0";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";

    pre-commit-hooks-nix.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks-nix.inputs.flake-utils.follows = "flake-utils";
    pre-commit-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";

    veloren.url = "gitlab:veloren/veloren/v0.15.0";
    veloren.inputs.nixpkgs.follows = "nixpkgs";
    veloren.inputs.parts.follows = "flake-parts";
  };

  outputs = { flake-parts, flake-utils, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      debug = true;
      systems = [ flake-utils.lib.system.x86_64-linux ];

      imports = [
        ./fp/devshell.nix
        ./fp/ctrs.nix
      ];
    };
}
