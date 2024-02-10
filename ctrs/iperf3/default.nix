# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, iperf3
}:
let
  name = iperf3.pname;
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = iperf3.version;

  contents = [ iperf3 ];

  config = {
    Entrypoint = [ "iperf3" ];
    Env = [ "PATH=/bin" ];
    ExposedPorts = { "5201" = { }; };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
    Volumes = { "/tmp" = { }; };
  };
}
