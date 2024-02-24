# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, prowlarr
}:
let
  name = prowlarr.pname;
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = prowlarr.version;

  contents = [
    dockerTools.caCertificates
    dockerTools.fakeNss
    prowlarr
  ];

  config = {
    Entrypoint = [ "Prowlarr" "-nobrowser" "-data=/data" ];
    Env = [ "PATH=/bin" ];
    ExposedPorts = { "9696/tcp" = { }; };
    Volumes = { "/data" = { }; };
  };
}
