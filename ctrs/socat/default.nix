# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, socat
}:
let
  name = socat.pname;
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = socat.version;


  contents = [ socat ];

  config = {
    Entrypoint = [ "socat" ];
  };
}
