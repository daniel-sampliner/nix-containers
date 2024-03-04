# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, curl
, dnsmasq
, iproute2-iptables-legacy
, iptables-legacy
, is-online
, jq
, mkS6RC
, openresolv
, procps
, s6
, util-linuxMinimal
, wireguard-tools
, writeTextDir
, writers
}:
let
  name = "wireguard";

  iproute2 = iproute2-iptables-legacy;
  wg-tools = (wireguard-tools.override {
    inherit iproute2;
    iptables = iptables-legacy;
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

  s6RC = mkS6RC { verbose = 5; } ./s6-rc;

  resolvconf-conf = writeTextDir "etc/resolvconf.conf" ''
    libc=NO
    named=NO
    pdnsd=NO
    unbound=NO

    dnsmasq_restart="${s6}/bin/s6-svc -r /run/service/dnsmasq"
    dnsmasq_conf=/run/dnsmasq.conf.d/10-openresolv.conf
    dnsmasq_resolv=/run/resolv.conf
  '';

  dnsmasq-conf = writeTextDir "/etc/dnsmasq.conf" ''
    interface=lo
    resolv-file=/run/resolv.conf
    clear-on-reload

    conf-dir=/run/dnsmasq.conf.d,*.conf
  '';

  healthcheck = writers.writeExecline { } "/bin/healthcheck" ''
    if { s6-rc -b diff }

    s6-setuidgid 65534:65534

    multisubstitute {
      define ipCheckerUrl https://icanhazip.com
      define ips /run/protonvpn-ips
    }

    emptyenv -c
    if { is-online }
    backtick -E ip { curl -4 --fail --silent --show-error
      --max-time 1 --retry-max-time 10 --retry 10
      $ipCheckerUrl }
    look $ip $ips
  '';
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = wireguard-tools.version;

  contents = [
    resolvconf-conf

    coreutils
    curl
    dnsmasq
    dnsmasq-conf
    dockerTools.caCertificates
    dockerTools.fakeNss
    healthcheck
    iproute2
    is-online
    jq
    openresolv
    s6RC
    util-linuxMinimal
    wg-tools
  ];

  config = {
    Entrypoint = [ "/init" ];
    Healthcheck = {
      Test = [ "CMD" "healthcheck" ];
      StartInterval = 5 * 1000000000;
      StartPeriod = 60 * 1000000000;
    };
    Volumes = { "/run" = { }; };
  };

  passthru = { inherit s6RC; };
}
