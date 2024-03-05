# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, curl
, findutils
, gavin-bc
, jq
, mkS6RC
, snooze
, writers
}:
let
  name = "docker-restart-unhealthy";

  s6RC = mkS6RC { } ./s6-rc;

  curl-docker = writers.writeExecline { flags = "-WS0"; } "/bin/curl-docker" ''
    emptyenv -c curl
      --silent --show-error --fail --retry 10 --max-time 3
      --unix-socket /var/run/docker.sock
      $@
  '';

  ls-containers = writers.writeExecline { flags = "-WS1"; } "/bin/ls-containers" ''
    emptyenv -c pipeline
      { curl-docker http://./containers/json
        --url-query filters={\"health\":[\"''${1}\"]} }
      jq -er ".[] | select(.Id | test(\"^[0-9a-f]+$\")) | [.Id, .Names] | flatten | @tsv"
  '';
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = "0.0.3";

  contents = [
    coreutils
    curl
    curl-docker
    findutils
    gavin-bc
    jq
    ls-containers
    s6RC
    snooze
  ];

  config = {
    Entrypoint = [ "/init" ];
    Env = [
      "FAILING_STREAK=3"
      "RESTART_STREAK=5"
      "XDG_DATA_HOME=/data"
    ];
    Volumes = {
      "/data" = { };
      "/run" = { };
    };
  };
}
