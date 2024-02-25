# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, curl
, syncthing
}:
let
  name = syncthing.pname;
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = syncthing.version;

  contents = [
    curl
    dockerTools.caCertificates
    syncthing
  ];

  config = {
    Cmd = [
      "serve"
      "--no-default-folder"
      "--no-browser"
      "--no-restart"
    ];
    Entrypoint = [ "syncthing" ];
    Env = [
      "PATH=/bin"
      "STCONFDIR=/config"
      "STDATADIR=/data"
    ];
    ExposedPorts = {
      "21027/udp" = { };
      "22000/tcp" = { };
      "22000/udp" = { };
    };
    Healthcheck = {
      Test = [
        "CMD"
        "curl"
        "-fsSk"
        "https://localhost:8384/rest/noauth/health"
      ];
    };
    Volumes = {
      "/config" = { };
      "/data" = { };
    };
  };
}
