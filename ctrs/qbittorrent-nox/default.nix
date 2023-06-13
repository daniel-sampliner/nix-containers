# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, qbittorrent-nox

, created ? "1970-01-01T00:00:01Z"
}:
let
  name = qbittorrent-nox.pname;
in
dockerTools.streamLayeredImage {
  inherit name created;
  tag = qbittorrent-nox.version;

  maxLayers = 125;

  contents = [ qbittorrent-nox ];
}
