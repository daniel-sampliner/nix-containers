# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, curl
, execline
, gawk
, killall
, lib
, wine64
, writeTextFile
, xorg
, xvfb-run

, created ? "1970-01-01T00:00:01Z"
}:
let
  name = "v_rising";

  entrypoint =
    let
      runtimeInputs = [
        coreutils
        killall
        wine64
        xorg.xorgserver
        xvfb-run
      ];
    in
    writeTextFile {
      name = "entrypoint";
      executable = true;
      destination = "/entrypoint";
      text = ''
        #!${execline}/bin/execlineb -WP

        importas -D "" path PATH
        export PATH "${lib.makeBinPath runtimeInputs}":$path

        importas -D /game GAME_DIR GAME_DIR
        importas -D /data DATA_DIR DATA_DIR
        define default_settings ''${GAME_DIR}/VRisingServer_Data/StreamingAssets/Settings
        define settings ''${DATA_DIR}/Settings

        if {
          forx -E -o 0 f { ServerGameSettings.json ServerHostSettings.json }
            ifelse { eltest ! -f ''${settings}/''${f} }
              { install -v -Dm0644
                ''${default_settings}/''${f} ''${settings}/''${f} }
              exit 0
        }

        trap { default {
          importas SIGNAL SIGNAL
          killall -e -s $SIGNAL -v VRisingServer.exe
        } }

        xvfb-run --auto-display --
          wine64
            ''${GAME_DIR}/VRisingServer.exe -persistentDataPath ''${DATA_DIR}
      '';
    };

  healthcheck =
    let
      runtimeInputs = [
        curl
        gawk
      ];
    in
    writeTextFile {
      name = "healthcheck";
      executable = true;
      destination = "/healthcheck";
      text = ''
        #!${execline}/bin/execlineb -WP

        importas -D "" path PATH
        export PATH "${lib.makeBinPath runtimeInputs}":$path

        backtick -E uptime
          { pipeline
            { curl -sS localhost:9090/metrics }
            awk "/^vr_uptime_seconds /{print $NF; exit}" }

        if { eltest -n $uptime } eltest $uptime -gt 0
      '';
    };
in
dockerTools.streamLayeredImage {
  inherit name created;
  tag = "0.0.1";

  maxLayers = 125;

  contents = [
    dockerTools.binSh
    dockerTools.caCertificates
    entrypoint
    healthcheck
  ];

  config = {
    Entrypoint = [ "/entrypoint" ];
    Env = [
      "WINEPREFIX=/wine"
      "VR_API_ENABLED=true"
    ];
    ExposedPorts = {
      "9876/udp" = { };
      "9877/udp" = { };
    };
    Healthcheck = {
      Test = [ "CMD" "/healthcheck" ];
      StartPeriod = 120 * 1000000000;
      StartInterval = 10 * 1000000000;
    };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
    StopSignal = "SIGINT";
    Volumes = {
      "/data" = { };
      "/game" = { };
      "/wine" = { };
    };
  };

}
