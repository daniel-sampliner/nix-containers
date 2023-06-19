# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils

, created ? "1970-01-01T00:00:01Z"
}:
dockerTools.streamLayeredImage {
  inherit created;

  name = coreutils.pname;
  tag = coreutils.version;

  contents = [ coreutils ];
  maxLayers = 125;

  config = {
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/coreutils";
    };
  };
}
