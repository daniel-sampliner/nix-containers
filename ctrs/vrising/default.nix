# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, execline
, killall
, lib
, logrotate
, rustPlatform
, wineWowPackages
, writeTextFile
, xorg

, created ? "1970-01-01T00:00:01Z"
}:
let
  name = "v_rising";

  winePkg = wineWowPackages.stagingFull;

  fontconfig = lib.pipe winePkg.buildInputs [
    (builtins.filter (d: d.pname == "fontconfig"))
    builtins.head
  ];

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
        winePkg
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

        if { wineboot }
        wine /game/VRisingServer.exe -persistentDataPath /data
      '';
    };

  healthcheck =
    let
      src = builtins.path { path = ./.; name = "healthcheck"; };
      cargo = lib.pipe "${src}/Cargo.toml" [
        builtins.readFile
        builtins.fromTOML
      ];

      lockFile = "${src}/Cargo.lock";
    in
    rustPlatform.buildRustPackage {
      pname = cargo.package.name;
      inherit (cargo.package) version;
      inherit src;

      cargoLock = { inherit lockFile; };
      cargoDeps = rustPlatform.importCargoLock { inherit lockFile; };

      postInstall = ''
        mv $out/bin/healthcheck $out/healthcheck
        rmdir $out/bin
      '';
    };
in
dockerTools.streamLayeredImage {
  inherit name created;
  tag = "0.0.4";

  maxLayers = 125;

  contents = [
    dockerTools.binSh
    dockerTools.caCertificates
    entrypoint
    fontconfig.out
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

  passthru = { inherit healthcheck; };
}
