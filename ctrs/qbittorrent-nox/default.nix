# SPDX-FileCopyrightText: 2023 - 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, curl
, lib
, qbittorrent-nox
, writeText
, writers
}:
let
  name = qbittorrent-nox.pname;

  config = writeText "qBittorrent.conf" ''
    [LegalNotice]
    Accepted=true
  '';

  entrypoint = writers.writeExecline { } "/entrypoint" ''
    importas -i path PATH
    export PATH ${lib.makeBinPath [coreutils]}:$path
    importas -i XDG_CONFIG_HOME XDG_CONFIG_HOME
    importas -i XDG_DATA_HOME XDG_DATA_HOME
    define confDir ''${XDG_CONFIG_HOME}/qBittorrent
    define logDir ''${XDG_DATA_HOME}/qBittorrent/logs
    define log ''${logDir}/qbittorrent.log

    execline-umask 022

    if { mkdir -p $logDir }
    ifelse
      { eltest -f $log }
      { foreground { fdmove -c 1 2 printf "log %s exists! move it first!\n" $log }
        exit 1 }
    if { ln -sfv /proc/self/fd/2 $log }

    if { mkdir -p $confDir }
    if { cp
      --backup=numbered --update --no-preserve=all --verbose
      ${config} ''${confDir}/qBittorrent.conf }

    emptyenv -c
    stdbuf -oL qbittorrent-nox
  '';
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = qbittorrent-nox.version;

  contents = [
    entrypoint
    coreutils
    dockerTools.caCertificates
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
      Test = [ "CMD" "${curl}/bin/curl" "-qsSf" "localhost:8080/api/v2/app/version" ];
    };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
  };
}
