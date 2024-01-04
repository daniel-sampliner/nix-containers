# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, curl
, execline
, iptables-legacy
, wireguard-tools
, writeTextFile
}:
let
  name = "wireguard";

  wg-tools = (wireguard-tools.override { iptables = iptables-legacy; }).overrideAttrs (_: prev: {
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

  entrypoint = writeTextFile {
    name = "entrypoint";
    executable = true;
    destination = "/entrypoint";
    text =
      let conf = "/etc/wireguard/wg0.conf";
      in ''
        #!${execline}/bin/execlineb -WP
        if {
          importas -i -u -n WG_CONFIG WG_CONFIG
          execline-umask 077
          if { mkdir -p ${builtins.dirOf conf} }
          redirfd -w 1 ${conf} echo $WG_CONFIG
        }
        if { wg-quick up ${conf} }

        chroot --userspec=65534:65534 / sleep +inf
      '';
  };

  healthcheck = writeTextFile {
    name = "healthcheck";
    executable = true;
    destination = "/healthcheck";
    text =
      let
        curlCmd = "curl --fail --silent --show-error "
          + "--max-time 3 --retry 5 --retry-max-time 25";
        endpoint = "https://icanhazip.com";
      in
      ''
        #!${execline}/bin/execlineb -WP
        backtick -E PUB_IP { ${curlCmd} --interface eth0 ${endpoint} }
        backtick -E VPN_IP { ${curlCmd} --interface wg0 ${endpoint} }
        eltest $PUB_IP != $VPN_IP
      '';
  };
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = wireguard-tools.version;

  contents = [
    coreutils
    curl
    dockerTools.caCertificates
    entrypoint
    healthcheck
    wg-tools
  ];

  config = {
    Entrypoint = [ "/entrypoint" ];
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

  passthru = {
    inherit wg-tools;
  };
}
