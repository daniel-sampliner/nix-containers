# SPDX-FileCopyrightText: 2023 - 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, curl
, is-online
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
    export PATH ${lib.makeBinPath [coreutils qbittorrent-nox]}:$path
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

  healthcheck = writers.writeExecline { } "/entrypoint" ''
    importas -i path PATH
    export PATH ${lib.makeBinPath [curl is-online]}:$path

    if { is-online }
    curl -qsSf localhost:8080/api/v2/app/version
  '';
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = qbittorrent-nox.version;

  contents = [
    dockerTools.caCertificates
    entrypoint
    healthcheck
  ];

  config = {
    Entrypoint = [ "/entrypoint" ];
    Env = [
      "XDG_CONFIG_HOME=/config"
      "XDG_DATA_HOME=/data"
      "XDG_CACHE_HOME=/cache"
    ];
    ExposedPorts = { "8080/tcp" = { }; };
    Healthcheck = { Test = [ "CMD" "/healthcheck" ]; };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
  };
}
