# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, chrony
, writeTextFile

, created ? "1970-01-01T00:00:01Z"
}:
let
  name = chrony.pname;

  chrony-conf = writeTextFile {
    name = "chrony.conf";
    destination = "/etc/chrony.conf";
    text = ''
      bindcmdaddress 0.0.0.0
      bindcmdaddress ::
      cmdallow all

      driftfile /data/drift
      dumpdir /data
      pidfile /run/chrony/chronyd.pid
      rtconutc
      rtcsync

      sourcedir /config
    '';
  };
in
dockerTools.streamLayeredImage {
  inherit name created;
  tag = chrony.version;

  maxLayers = 125;

  contents = [
    chrony
    chrony-conf
    dockerTools.fakeNss
  ];

  extraCommands = ''
    mkdir config data run
  '';

  config = {
    Cmd = [ "-d" "-r" "-s" "-F" "1" "-u" "nobody" ];
    Entrypoint = [ "chronyd" ];
    Healthcheck = {
      Test = [ "CMD" "chronyc" "waitsync" "1" ];
      StartInterval = 1 * 1000000000;
      StartPeriod = 60 * 1000000000;
      Timeout = 11 * 1000000000;
    };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
    Volumes = {
      "/config" = { };
      "/data" = { };
    };
  };
}
