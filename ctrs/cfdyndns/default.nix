# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, execline
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
        #!${execline}/bin/execlineb -WS2

        importas -D "" path PATH
        export PATH "${lib.makeBinPath runtimeInputs}":$path

        execline-cd /lib/cfdyndns
        if { terraform init }

        case -s $1 {
          wait { snooze -v -H* -M* -S* -t /data/last -T $2 $0 go $2 }
          go {
            if { terraform apply -auto-approve -input=false }
              s6-touch /data/last
          }
        }

        foreground
          { fdmove -c 1 2 s6-echo unknown stage $1 }
          exit 1
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
  ];

  extraCommands = ''
    install -Dm0777 -d lib/cfdyndns
    install -Dm0444 ${./main.tf} lib/cfdyndns/main.tf
  '';

  config = {
    Cmd = [ "5m" ];
    Entrypoint = [ "/entrypoint" "wait" ];
    Volumes = { "/data" = { }; };
  };
}
