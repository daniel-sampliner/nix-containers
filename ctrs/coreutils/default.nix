# SPDX-FileCopyrightText: 2023 - 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, dash
, execline
}:
let
  name = coreutils.pname;
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = coreutils.version;

  contents = [ coreutils dash execline ];

  extraCommands = ''
    ln -sf dash bin/sh
  '';

  config = {
    Env = [ "PATH=/bin" ];
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
  };
}
