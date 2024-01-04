# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, curl
, execline
, gawk
, jq
, lib
, libnatpmp
, s6-portable-utils
, snooze
, writeTextFile
, writers
}:
let
  name = "protonvpn-qbittorrent-port-forward";
  portFile = "/data/port";

  entrypoint =
    let
      natpmpCmd =
        let gateway = "10.2.0.1";
        in
        op:
          assert lib.asserts.assertOneOf "op" op [ "check" "tcp" "udp" ];
          "fdmove -c 2 1 natpmpc -g ${gateway}"
          + (if op == "check" then "" else " -a 1 0 ${op} 60");

      getPort = let awk = "${gawk}/bin/awk"; in writers.makeScriptWriter
        {
          interpreter = "${awk} -f";
          check = "${awk} -o -f";
        }
        "get-port"
        ''
          BEGIN { ret = 1 }

          { print > "/dev/stderr" }
          match($0, /^Mapped public port ([0-9]+) protocol (TCP|UDP)/, m) {
            print m[1]
            ret = 0
          }

          END { exit $ret }
        '';

      curlCmd = "curl --fail --silent --show-error --max-time 3 --retry 5";
    in
    writeTextFile {
      name = "entrypoint";
      executable = true;
      destination = "/entrypoint";
      text = ''
        #!${execline}/bin/execlineb -WP

        if { s6-maximumtime 10000 ${natpmpCmd "check"} }

        trap {
          SIGTERM { s6-nuke -t }
          SIGINT  { s6-nuke -t }
        }

        loopwhilex
          if { snooze -v -H* -M* -S* -t ${portFile} -T 45 }
          s6-maximumtime 55000
          background { redirfd -w 1 /dev/null pipeline { ${natpmpCmd "tcp"} } ${getPort} }
          importas -i -u bgPID !
          backtick -E port { pipeline { ${natpmpCmd "udp"} } ${getPort} }
          foreground { fdmove 1 2 s6-echo PORT: $port }
          if { ${curlCmd}
            --data-urlencode "json={\"listen_port\":''${port}}"
            localhost:8080/api/v2/app/setPreferences }
          if {
            pipeline { ${curlCmd} localhost:8080/api/v2/app/preferences }
            redirfd -w 1 /dev/null jq -e ".listen_port == ''${port}"
          }
          redirfd -w 1 ${portFile} s6-echo $port
          wait $bgPID
      '';
    };

  healthcheck = writeTextFile {
    name = "healthcheck";
    executable = true;
    destination = "/healthcheck";
    text = ''
      #!${execline}/bin/execlineb -WP
      eltest -f ${portFile}
    '';
  };
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = "0.0.1";

  contents = [
    curl
    entrypoint
    healthcheck
    jq
    libnatpmp
    s6-portable-utils
    snooze
  ];

  config = {
    Entrypoint = [ "/entrypoint" ];
    Healthcheck = {
      Test = [ "CMD" "/healthcheck" ];
      StartPeriod = 3 * 1000000000;
      StartInterval = 1 * 1000000000;
    };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
    Volumes = { "/data" = { }; };
  };

  passthru = { inherit entrypoint; };
}
