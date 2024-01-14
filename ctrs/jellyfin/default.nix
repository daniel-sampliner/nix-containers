# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, curl
, jellyfin
}:
let
  name = jellyfin.pname;
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = jellyfin.version;

  contents = [
    dockerTools.fakeNss
    dockerTools.caCertificates
    jellyfin
  ];

  config = {
    Entrypoint = [ "jellyfin" ];
    Env = [
      "JELLYFIN_CACHE_DIR=/cache"
      "JELLYFIN_CONFIG_DIR=/config"
      "JELLYFIN_DATA_DIR=/data"
      "JELLYFIN_LOG_DIR=/log"
    ];
    ExposedPorts = {
      "8096/tcp" = { };
      "8920/tcp" = { };
      "7359/udp" = { };
    };
    Healthcheck = {
      Test = [ "CMD" "${curl}/bin/curl" "-qsSf" "http://localhost:8096/health" ];
    };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
    Volumes = {
      "/cache" = { };
      "/config" = { };
      "/data" = { };
      "/log" = { };
    };
  };
}
