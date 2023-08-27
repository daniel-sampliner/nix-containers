# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, execline
, killall
, lib
, s6-portable-utils
, snooze
, terraform
, writeTextFile

, created ? "1970-01-01T00:00:01Z"
}:
let
  name = "cfdyndns";
  my-tf = terraform.withPlugins (p: builtins.attrValues {
    inherit (p)
      cloudflare
      http
      ;
  });

  entrypoint =
    let
      runtimeInputs = [
        killall
        my-tf
        s6-portable-utils
        snooze
      ];
    in
    writeTextFile {
      name = "entrypoint";
      executable = true;
      destination = "/entrypoint";
      text = ''
        #!${execline}/bin/execlineb -WS1

        importas -D "" path PATH
        export PATH "${lib.makeBinPath runtimeInputs}":$path

        execline-cd /lib/cfdyndns

        trap { default {
          importas SIGNAL SIGNAL
          killall -e -s $SIGNAL -v terraform snooze
        } }

        if { terraform init }

        define -s tfapply "terraform apply -auto-approve -input=false"

        if -Xn { loopwhilex
          if { snooze -v -H* -M* -S* -t /data/last -T $1 }
          if { $tfapply } s6-touch /data/last }

        foreground { $tfapply -destroy }
        s6-rmrf /data/last
      '';
    };

  healthcheck = writeTextFile {
    name = "healthcheck";
    executable = true;
    destination = "/healthcheck";
    text = ''
      #!${execline}/bin/execlineb -WP
      eltest -f /data/last
    '';
  };
in
dockerTools.streamLayeredImage {
  inherit name created;
  tag = "0.0.1";

  maxLayers = 125;

  contents = [
    dockerTools.caCertificates
    entrypoint
    healthcheck
  ];

  extraCommands = ''
    install -Dm0777 -d lib/cfdyndns
    install -Dm0444 ${./main.tf} lib/cfdyndns/main.tf
  '';

  config = {
    Cmd = [ "5m" ];
    Entrypoint = [ "/entrypoint" ];
    Healthcheck = {
      Test = [ "CMD" "/healthcheck" ];
      StartPeriod = 10 * 1000000000;
      StartInterval = 1 * 1000000000;
    };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
    Volumes = { "/data" = { }; };
    StopSignal = "SIGINT";
  };
}
