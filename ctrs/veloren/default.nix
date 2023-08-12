# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, execline
, netcat-openbsd
, veloren-server-cli
, veloren-voxygen
, writeTextFile

, created ? "1970-01-01T00:00:01Z"
}:
let
  name = veloren-server-cli.pname;

  healthcheck = writeTextFile {
    name = "healthcheck";
    executable = true;
    destination = "/healthcheck";
    text = ''
      #!${execline}/bin/execlineb -WS2

      backtick -E ret {
        pipeline { ${netcat-openbsd}/bin/nc -dNw2 $1 $2 }
          ${coreutils}/bin/tr -dc [:graph:]
      }
      eltest $ret = VELOREN
    '';
  };
in
dockerTools.streamLayeredImage {
  inherit name created;
  tag = veloren-server-cli.version;

  maxLayers = 125;

  contents = [
    dockerTools.caCertificates
    healthcheck
    veloren-server-cli
  ];

  config = {
    Entrypoint = [ "veloren-server-cli" ];
    Env = [
      "RUST_BACKTRACE=full"
      "VELOREN_USERDATA=/data"
    ];
    ExposedPorts = {
      "14004/tcp" = { };
      "14005/tcp" = { };
    };
    Healthcheck = {
      Test = [
        "CMD"
        "/healthcheck"
        "127.0.0.1"
        "14004"
      ];
      StartPeriod = 15 * 1000000000;
      Timeout = 3 * 1000000000;
    };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
    StopSignal = "SIGUSR1";
    Volumes = { "/data" = { }; };
  };

  passthru = { inherit veloren-server-cli veloren-voxygen; };
}
