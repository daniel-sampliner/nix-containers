# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, catatonit
, coreutils
, curl
, iproute2
, iptables-legacy
, is-online
, jq
, procps
, snooze
, util-linuxMinimal
, wireguard-tools
, writers
}:
let
  name = "wireguard";

  wg-tools = (wireguard-tools.override {
    iptables = iptables-legacy;
    iproute2 = iproute2.override { iptables = iptables-legacy; };
    procps = procps.override { withSystemd = false; };
  }).overrideAttrs (_: prev: {
    patchFlags = "-p2";
    patches = prev.patches or [ ] ++ [
      ./0001-wg-quick-set-sysctl-only-if-necessary.patch
      ./0002-wg-quick-dont-use-iptables-raw-table.patch
    ];
    makeFlags = prev.makeFlags or [ ] ++ [
      "WITH_BASHCOMPLETION=no"
    ];
    postFixup = prev.postFixup or "" + ''
      rm -rf $out/lib/systemd
    '';
  });

  marker = "/run/marker";

  entrypoint = writers.writeExecline { } "/entrypoint" ''
    export LC_ALL C
    importas -i WG_CONFIG WG_CONFIG

    define conf /run/wireguard/wg0.conf
    define ips /run/protonvpn-ips
    define ipCheckerUrl https://icanhazip.com
    define protonServersUrl https://api.protonmail.ch/vpn/logicals

    define -s curl "curl --retry 5 --fail --silent --show-error"

    execline-umask 077

    if { pipeline { $curl --max-time 5 --retry-max-time 30 $protonServersUrl }
      pipeline { jq -er --stream "select(.[0][4] == \"ExitIP\") | .[1]" }
      redirfd -w 1 $ips sort -u }
    if { eltest -s $ips }
    foreground { fdmove -c 1 2 printf "downloaded protonvpn IPs\n" }

    if { mkdir -p /run/wireguard }
    if { redirfd -w 1 $conf printf "%s\n" $WG_CONFIG }
    if { wg-quick up $conf }

    emptyenv -c
    loopwhilex
      if { snooze -H* -M* -S* -t ${marker} -T 30 }
      if { is-online }
      backtick -E ip { $curl -4 --max-time 1 --retry-max-time 10 $ipCheckerUrl }
      if { redirfd -w 1 /dev/null look $ip $ips }
      touch ${marker}
  '';

  healthcheck = writers.writeExecline { } "/healthcheck" ''
    if { eltest -f ${marker} }
    if { touch -d -30seconds /run/last }
    eltest ${marker} -nt /run/last
  '';
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = wireguard-tools.version;

  contents = [
    catatonit
    coreutils
    curl
    dockerTools.caCertificates
    entrypoint
    healthcheck
    is-online
    jq
    snooze
    util-linuxMinimal
    wg-tools
  ];

  config = {
    Entrypoint = [ "/bin/catatonit" "-g" "--" "/entrypoint" ];
    Healthcheck = {
      Test = [ "CMD" "/healthcheck" ];
      StartPeriod = 5 * 1000000000;
      StartInterval = 1 * 1000000000;
    };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
  };
}
