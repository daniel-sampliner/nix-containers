# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, catatonit
, coreutils
, lib
, opentofu
, snooze
, stdenvNoCC
, writers
}:
let
  name = "cf-zerotrust";
  my-tf = opentofu.withPlugins (p: builtins.attrValues {
    inherit (p)
      cloudflare
      dns
      ;
  });

  tf-data = stdenvNoCC.mkDerivation {
    name = "tf-data";
    src = builtins.path {
      name = "tf-data-src";
      path = builtins.filterSource
        (path: type: type == "directory" || lib.hasSuffix ".tf" path)
        ./.;
    };

    buildInputs = [ my-tf ];

    buildPhase = ''
      tofu init -backend=false
    '';

    installPhase = ''
      rm -rf .terraform
      cp -a . $out
    '';
  };

  entrypoint = writers.writeExecline { } "/bin/entrypoint" ''
    backtick -E minutes { pipeline { seq 0 29 } shuf -n 1 }
    backtick -E seconds { pipeline { seq 0 59 } shuf -n 1 }

    if { cp -r ${tf-data}/. . }
    if { tofu init }

    loopwhilex
      if { snooze -v -t /data/last -s 30m -H* -M''${minutes}/30 -S''${seconds} }
      if { tofu apply -auto-approve -input=false }
      touch /data/last
  '';

  healthcheck = writers.writeExecline { } "/bin/healthcheck" ''
    if { eltest -f /data/last }
    if { touch --date="-30 minutes" check }
    eltest /data/last -nt check
  '';

in
dockerTools.streamLayeredImage {
  inherit name;
  tag = "0.0.1";

  contents = [
    catatonit
    coreutils
    dockerTools.caCertificates
    entrypoint
    healthcheck
    my-tf
    snooze
  ];

  config = {
    Entrypoint = [ "catatonit" "-g" "--" "entrypoint" ];
    Env = [ "PATH=/bin" ];
    Healthcheck = {
      Test = [ "CMD" "healthcheck" ];
      StartPeriod = 60 * 1000000000;
    };
    WorkingDir = "/run/tf";
    Volumes = { "/data" = { }; };
  };

  passthru = { inherit tf-data; };
}
