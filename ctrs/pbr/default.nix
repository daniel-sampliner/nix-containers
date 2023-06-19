# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, bash
, coreutils
, iproute2
, writeScriptBin
, xxHash

, created ? "1970-01-01T00:00:01Z"
}:
let
  name = "pbr";
  pbr = writeScriptBin "pbr" (builtins.replaceStrings
    [ "#!/usr/bin/env bash\n" ]
    [ "#!${bash}/bin/bash\n" ]
    (builtins.readFile ./pbr));
in
dockerTools.streamLayeredImage {
  inherit name created;

  maxLayers = 125;

  contents = [
    coreutils
    iproute2
    pbr
    xxHash
  ];

  config = {
    Entrypoint = [ "pbr" ];
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
  };
}
