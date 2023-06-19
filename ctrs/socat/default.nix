# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, socat

, created ? "1970-01-01T00:00:01Z"
}:
let
  name = socat.pname;
in
dockerTools.streamLayeredImage {
  inherit name created;
  tag = socat.version;

  maxLayers = 125;

  config = {
    Entrypoint = [ "${socat}/bin/socat" ];
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
  };
}
