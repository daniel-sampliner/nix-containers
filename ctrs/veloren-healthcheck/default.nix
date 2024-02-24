# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, execline
, netcat-openbsd
, s6-portable-utils
, writeTextFile
}:
let
  name = "veloren-healthcheck";
  healthcheck = writeTextFile {
    name = "healthcheck";
    executable = true;
    destination = "/healthcheck";
    text = ''
      #!${execline}/bin/execlineb -WS2

      backtick -E ret {
        pipeline
          { ${netcat-openbsd}/bin/nc -dNw2 $1 $2 }
          ${coreutils}/bin/tr -dc [:graph:]
      }
      eltest $ret = VELOREN
    '';
  };
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = "0.0.1";


  contents = [
    healthcheck
    s6-portable-utils
  ];

  config = {
    Entrypoint = [ "s6-pause" ];
  };
}
