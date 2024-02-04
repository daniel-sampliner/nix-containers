# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, catatonit
, coreutils
, curl
, gawk
, jq
, lib
, libnatpmp
, snooze
, writers
}:
let
  name = "protonvpn-qbittorrent-port-forward";
  portFile = "/run/port";

  natpmpCmd =
    let gateway = "10.2.0.1";
    in
    op:
      assert lib.asserts.assertOneOf "op" op [ "check" "tcp" "udp" ];
      "natpmpc -g ${gateway}"
      + (if op == "check" then "" else " -a 1 0 ${op} 60");

  mainLoop =
    let
      getPort = let awk = "${gawk}/bin/awk"; in writers.makeScriptWriter
        {
          interpreter = "${awk} -f";
          check = "${awk} -o -f";
        }
        "get-port"
        ''
          BEGIN { ret = 1 }

          match($0, /^Mapped public port ([0-9]+) protocol (TCP|UDP)/, m) {
            print m[1]
            ret = 0
          }

          END { exit $ret }
        '';

      curlCmd = "curl --fail --silent --show-error --max-time 3 --retry 5";
    in
    writers.writeExecline { } "/bin/mainloop" ''
      emptyenv -c

      background { redirfd -w 1 /dev/null ${natpmpCmd "tcp"} }
      importas -i -u bgPID !

      backtick -E port { pipeline { ${natpmpCmd "udp"} } ${getPort} }
      if { ${curlCmd}
        --data-urlencode "json={\"listen_port\":''${port}}"
        localhost:8080/api/v2/app/setPreferences }
      if { pipeline { ${curlCmd} localhost:8080/api/v2/app/preferences }
        redirfd -w 1 /dev/null jq -e ".listen_port == ''${port}" }
      if { redirfd -w 1 ${portFile} printf "%s\n" $port }
      wait $bgPID
    '';

  entrypoint =
    let
      runtimeInputs = [
        coreutils
        curl
        jq
        libnatpmp
        snooze
      ];
    in
    writers.writeExecline { } "/entrypoint" ''
      importas -i path PATH
      export PATH ${lib.makeBinPath runtimeInputs}:$path

      if { curl
        --fail --silent --show-error --max-time 3 --retry 10 --retry-connrefused
        localhost:8080/api/v2/app/version }
      if { printf "\n" }

      if { touch --date "60 seconds" /run/end }
      if { loopwhilex -x 0,69
        if { touch /run/now }
        ifelse -n { eltest /run/end -nt /run/now } { foreground { fdmove -c 1 2 echo timeout } exit 69 }
        timeout 10 ${natpmpCmd "check"} }
      if { rm -- /run/end /run/now }

      emptyenv -c
      loopwhilex
        if { snooze -H* -M* -S* -t ${portFile} -T 45 }
        timeout 55 mainloop
    '';

  healthcheck = writers.writeExecline { } "/healthcheck" ''
    importas -i path PATH
    export PATH ${lib.makeBinPath [coreutils]}:$path

    if { eltest -f ${portFile} }
    if { touch -d -60seconds /run/last }
    eltest ${portFile} -nt /run/last
  '';
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = "0.0.4";

  contents = [
    catatonit
    entrypoint
    healthcheck
    mainLoop
  ];

  config = {
    Entrypoint = [ "/bin/catatonit" "-g" "--" "/entrypoint" ];
    Healthcheck = {
      Test = [ "CMD" "/healthcheck" ];
      StartPeriod = 60 * 1000000000;
      StartInterval = 5 * 1000000000;
    };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
    Volumes = { "/data" = { }; };
  };
}
