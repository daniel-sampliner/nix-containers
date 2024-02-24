# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, sonarr
}:
let
  name = sonarr.pname;
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = sonarr.version;

  contents = [
    dockerTools.caCertificates
    dockerTools.fakeNss
    sonarr
  ];

  config = {
    Entrypoint = [ "NzbDrone" "-nobrowser" "-data=/data" ];
    Env = [ "PATH=/bin" ];
    ExposedPorts = { "8989/tcp" = { }; };
    Volumes = { "/data" = { }; };
  };
}
