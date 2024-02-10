# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, netperf
}:
let
  name = netperf.pname;
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = netperf.version;

  contents = [ netperf ];

  config = {
    Env = [ "PATH=/bin" ];
    ExposedPorts = { "12865" = { }; };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
  };
}
