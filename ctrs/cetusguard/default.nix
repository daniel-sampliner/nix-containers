# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL
{ dockerTools
, buildGoModule
, curl
, dash
, writeTextFile

, src
}:
let
  name = "cetusguard";
  version = "1.0.6";

  cetusguard = buildGoModule {
    pname = name;
    inherit version src;

    vendorHash = null;
  };

  healthcheck = writeTextFile {
    name = "healthcheck";
    destination = "/healthcheck";
    executable = true;
    text = ''
      #!${dash}/bin/dash
      set -eu
      ${curl}/bin/curl -sS \
        --unix-socket "''${CETUSGUARD_BACKEND_ADDR#unix://}" \
        localhost/_ping
    '';
  };
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = version;


  contents = [ cetusguard curl healthcheck ];

  config = {
    Entrypoint = [ "cetusguard" ];
    Env = [
      "CETUSGUARD_FRONTEND_ADDR=tcp://:2375"
      "CETUSGUARD_BACKEND_ADDR=unix:///var/run/docker.sock"
    ];
    ExposedPorts = { "2375/tcp" = { }; };
    Healthcheck = { Test = [ "CMD" "/healthcheck" ]; };
  };

  passthru = { inherit cetusguard; };
}
