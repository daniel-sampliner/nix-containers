# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, curl
, komga
}:
let
  name = komga.pname;
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = komga.version;


  contents = [ komga ];

  config = {
    Entrypoint = [ "komga" ];
    Env = [
      "KOMGA_CONFIGDIR=/config"
      "JAVA_TOOL_OPTIONS=\"-XX:MaxRAMPercentage=75\""
    ];
    ExposedPorts = { "8080/tcp" = { }; };
    Healthcheck = {
      Test = [
        "CMD"
        "${curl}/bin/curl"
        "-qsS"
        "localhost:25600"
      ];
      StartPeriod = 30 * 1000000000;
      Timeout = 3 * 1000000000;
    };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
  };
}
