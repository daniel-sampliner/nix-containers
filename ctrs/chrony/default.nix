# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, chrony
, writeTextFile
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
  inherit name;
  tag = chrony.version;

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
    Env = [ "PATH=/bin" ];
    Healthcheck = {
      Test = [ "CMD" "chronyc" "waitsync" "1" ];
      StartInterval = 1 * 1000000000;
      StartPeriod = 60 * 1000000000;
      Timeout = 11 * 1000000000;
    };
    Volumes = {
      "/config" = { };
      "/data" = { };
    };
  };
}
