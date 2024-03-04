# SPDX-FileCopyrightText: 2023 - 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, curl
, is-online
, jq
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

  entrypoint = writers.writeExecline { } "/bin/entrypoint" ''
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

  healthcheck = writers.writeExecline { } "/bin/healthcheck" ''
    importas -i path PATH
    export PATH ${lib.makeBinPath [coreutils curl is-online jq]}:$path

    define -s curl "curl -qsSf --max-time 1 --retry 10 --retry-max-time 15"

    if { $curl localhost:8080/api/v2/app/version }
    if { printf "\n" }
    ifelse
      { pipeline { $curl localhost:8080/api/v2/torrents/info }
        pipeline -w { head -n1 }
        jq -e --stream "select(.[0][1] == \"state\")[1]
          | select(. == \"moving\")" }
      { }
    is-online
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
    Entrypoint = [ "entrypoint" ];
    Env = [
      "XDG_CONFIG_HOME=/config"
      "XDG_DATA_HOME=/data"
      "XDG_CACHE_HOME=/cache"
    ];
    ExposedPorts = { "8080/tcp" = { }; };
    Healthcheck = {
      Test = [ "CMD" "healthcheck" ];
      StartInterval = 5 * 1000000000;
      StartPeriod = 60 * 1000000000;
    };
  };
}
