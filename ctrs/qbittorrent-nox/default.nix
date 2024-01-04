# SPDX-FileCopyrightText: 2023 - 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, curl
, execline
, qbittorrent-nox
, writeTextFile
, writeText
}:
let
  name = qbittorrent-nox.pname;

  config = writeText "qBittorrent.conf" ''
    [LegalNotice]
    Accepted=true
  '';

  entrypoint = writeTextFile {
    name = "entrypoint";
    executable = true;
    destination = "/entrypoint";
    text = ''
      #!${execline}/bin/execlineb -WP

      importas -i XDG_CONFIG_HOME XDG_CONFIG_HOME
      define confDir ''${XDG_CONFIG_HOME}/qBittorrent

      execline-umask 022
      if { mkdir -p $confDir }
      if { cp
        --backup=numbered --update --no-preserve=all --verbose
        ${config} ''${confDir}/qBittorrent.conf }
      stdbuf -oL qbittorrent-nox
    '';
  };
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = qbittorrent-nox.version;


  contents = [
    dockerTools.caCertificates
    coreutils
    entrypoint
    qbittorrent-nox
  ];

  config = {
    Entrypoint = [ "/entrypoint" ];
    Env = [
      "XDG_CONFIG_HOME=/config"
      "XDG_DATA_HOME=/data"
      "XDG_CACHE_HOME=/cache"
    ];
    ExposedPorts = { "8080/tcp" = { }; };
    Healthcheck = {
      Test = [ "CMD" "${curl}/bin/curl" "-qsS" "localhost:8080/api/v2/app/version" ];
    };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
  };
}
