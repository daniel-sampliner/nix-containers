# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, bash
, coreutils
, iproute2
, writeScriptBin
, xxHash
}:
let
  name = "pbr";
  pbr = writeScriptBin "pbr" (builtins.replaceStrings
    [ "#!/usr/bin/env bash\n" ]
    [ "#!${bash}/bin/bash\n" ]
    (builtins.readFile ./pbr));
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = "0.0.1";


  contents = [
    coreutils
    iproute2
    pbr
    xxHash
  ];

  config = {
    Entrypoint = [ "pbr" ];
  };
}
