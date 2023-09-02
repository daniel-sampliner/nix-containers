# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL
{ dockerTools
, buildGoModule
, curl
, dash
, writeTextFile

, src
, created ? "1970-01-01T00:00:01Z"
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
  inherit name created;
  tag = version;

  maxLayers = 125;

  contents = [ cetusguard curl healthcheck ];

  config = {
    Entrypoint = [ "cetusguard" ];
    Env = [
      "CETUSGUARD_FRONTEND_ADDR=tcp://:2375"
      "CETUSGUARD_BACKEND_ADDR=unix:///var/run/docker.sock"
    ];
    ExposedPorts = { "2375/tcp" = { }; };
    Healthcheck = { Test = [ "CMD" "/healthcheck" ]; };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
  };

  passthru = { inherit cetusguard; };
}
