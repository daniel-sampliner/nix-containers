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
, logrotate
, wineWowPackages
, writeTextFile
, xorg

, created ? "1970-01-01T00:00:01Z"
}:
let
  name = "v_rising";

  logrotate-conf = writeTextFile {
    name = "logrotate.conf";
    destination = "/etc/logrotate.conf";
    text = ''
      /game/BepInEx/*.log {
        rotate 8
        size 0
        missingok
        notifempty
      }
    '';
  };

  entrypoint =
    let
      runtimeInputs = [
        coreutils
        killall
        logrotate
        wineWowPackages.staging
        xorg.xorgserver
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

        define default_settings /game/VRisingServer_Data/StreamingAssets/Settings
        define settings /data/Settings

        if { logrotate --state /dev/null /etc/logrotate.conf }

        if {
          forx -E -o 0 f { ServerGameSettings.json ServerHostSettings.json }
            ifelse { eltest ! -f ''${settings}/''${f} }
              { install -v -Dm0644
                ''${default_settings}/''${f} ''${settings}/''${f} }
              exit 0
        }

        define bepinex /game/BepInEx

        trap { default {
          importas SIGNAL SIGNAL
          foreground { fdmove -c 1 2 echo signal: $SIGNAL }
          foreground { timeout 15 killall -s $SIGNAL -v -w VRisingServer.exe }
          kill -$SIGNAL -1
        } }

        background { Xvfb -screen 0 640x480x24 -nolisten tcp }
        background { if { eltest -d ''${bepinex} }
          tail -n+0 -F ''${bepinex}/LogOutput.log }

        export DISPLAY :0

        wine /game/VRisingServer.exe -persistentDataPath /data
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
    logrotate-conf
  ];

  config = {
    Entrypoint = [ "/entrypoint" ];
    Env = [
      "VR_API_ENABLED=true"
      "WINEPREFIX=/wine"
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
