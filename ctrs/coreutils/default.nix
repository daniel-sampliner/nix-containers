# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, dash
}:
let
  name = coreutils.pname;
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = coreutils.version;

  contents = [ coreutils dash ];

  extraCommands = ''
    ln -sf dash bin/sh
  '';

  config = {
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
  };
}
