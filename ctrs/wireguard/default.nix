# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, curl
, dnsmasq
, iproute2
, iptables-legacy
, is-online
, jq
, mkS6RC
, procps
, snooze
, util-linuxMinimal
, wireguard-tools
, writeTextDir
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

  s6RC = mkS6RC { verbose = 5; } ./s6-rc;

  resolvconf-conf = writeTextDir "etc/resolvconf.conf" ''
    libc=NO
    named=NO
    pdnsd=NO
    unbound=NO

    dnsmasq_conf=/run/dnsmasq.conf.d/openresolv.conf
    dnsmasq_resolv=/run/resolv.conf
  '';

  dnsmasq-conf = writeTextDir "/etc/dnsmasq.conf" ''
    interface=lo
    resolv-file=/run/resolv.conf
    clear-on-reload

    conf-dir=/run/dnsmasq.conf.d,*.conf
  '';

  entrypoint = writers.writeExecline { } "/bin/entrypoint" ''
    s6-setuidgid 65534:65534

    define ipCheckerUrl https://icanhazip.com
    define ips /run/protonvpn-ips

    emptyenv -c
    loopwhilex
      if { snooze -H* -M* -S* -t /run/marker -T 30 }
      if { is-online }
      backtick -E ip { curl -4 --fail --silent --show-error
        --max-time 1 --retry-max-time 60 --retry 10
        $ipCheckerUrl }
      redirfd -w 1 /dev/null look $ip $ips
  '';
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = wireguard-tools.version;

  contents = [
    coreutils
    curl
    dnsmasq
    dnsmasq-conf
    dockerTools.caCertificates
    dockerTools.fakeNss
    entrypoint
    iproute2
    is-online
    jq
    resolvconf-conf
    s6RC
    snooze
    util-linuxMinimal
    wg-tools
  ];

  config = {
    Entrypoint = [ "/init" ];
    Command = [ "entrypoint" ];
    Healthcheck = { Test = [ "CMD" "s6-rc" "-b" "diff" ]; };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
    Volumes = { "/run" = { }; };
  };

  passthru = { inherit s6RC; };
}
