# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, curl
, execline
, iptables-legacy
, jq
, s6
, s6-linux-init
, s6-portable-utils
, s6-rc
, snooze
, stdenvNoCC
, util-linuxMinimal
, wireguard-tools
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

  s6-init =
    let
      s6Dir = "/etc/s6";

      s6DB = "${s6Dir}/db";
      s6BaseDir = "${s6Dir}/basedir";
      s6MkFifos = "${s6BaseDir}/mkfifos";
      s6RunDir = "/run/s6";
      s6ContainerEnv = "${s6RunDir}/container_environment";
    in
    stdenvNoCC.mkDerivation {
      name = "s6-init";
      src = ./s6-init;

      inherit
        execline
        s6BaseDir
        s6ContainerEnv
        s6DB
        s6Dir
        s6MkFifos
        s6RunDir
        ;

      buildInputs = [
        s6-linux-init
        s6-portable-utils
        s6-rc
      ];

      patchPhase = ''
        find . -type f | while read -r ff; do
          substituteAllInPlace "$ff"
        done
      '';

      buildPhase = ''
        basedir=$PWD${s6BaseDir}
        mkdir -p ''${basedir%/*}
        s6-linux-init-maker \
          -NCB \
          -c ${s6BaseDir} \
          -t 2 \
          -s ${s6ContainerEnv} \
          -f ./skel \
          -- $basedir

        s6-rc-compile -v2 $PWD${s6DB} ./s6-rc.d

        find $basedir -type p \
          | tee >(xargs -r rm -- >&2) \
          | sed "s:$PWD${s6BaseDir}/run-image:/run:" \
          > $PWD${s6MkFifos}
      '';

      installPhase = ''
        mkdir -p $out/${s6Dir}
        s6-hiercopy $PWD/${s6Dir} $out/${s6Dir}

        mkdir -p $out/bin
        for file in $out/${s6BaseDir}/bin/*; do
          [[ ! -f $file ]] && continue
          ln -s ''${file#$out/} $out/bin/''${file##*/}
        done

        cp -a ./rootfs/. $out

        mkdir -p $out/var
        ln -s /run $out/var/run
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
    execline
    jq
    s6
    s6-init
    s6-rc
    snooze
    util-linuxMinimal
    wg-tools
  ];

  config = {
    Entrypoint = [ "/init" ];
    Healthcheck = {
      Test = [ "CMD" "/bin/s6-rc" "diff" ];
      StartPeriod = 5 * 1000000000;
      StartInterval = 1 * 1000000000;
    };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
  };

  passthru = {
    inherit wg-tools s6-init;
  };
}
