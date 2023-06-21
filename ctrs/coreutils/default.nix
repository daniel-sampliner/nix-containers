# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, dash

, created ? "1970-01-01T00:00:01Z"
}:
let
  name = coreutils.pname;
in
dockerTools.streamLayeredImage {
  inherit name created;
  tag = coreutils.version;

  contents = [ coreutils dash ];
  maxLayers = 125;

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
