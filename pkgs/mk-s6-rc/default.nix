# SPDX-FileCopyrightText: 2024 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ lib
, coreutils
, execline
, s6
, s6-linux-init
, s6-rc
, stdenvNoCC
, symlinkJoin
}:

{ timeoutMS ? 60000, verbose ? 1 }: src:
let
  runtimeInputs = [
    coreutils
    execline
    s6
    s6-rc
  ];

  s6BaseDir = "s6-linux-init/current";
  s6MkFifos = "${s6BaseDir}/mkfifos";
  s6RunDir = "/run/s6-linux-init";
  s6ContainerEnv = "${s6RunDir}/container-env";

  s6RCDir = "/etc/s6-rc/compiled";

  mkDrv = args: stdenvNoCC.mkDerivation ({
    inherit
      s6BaseDir
      s6MkFifos
      s6RunDir
      s6ContainerEnv
      s6RCDir

      timeoutMS
      verbose
      ;

    buildInputs = runtimeInputs;

    patchPhase = ''
      runHook prePatch

      find . -type f \
        | while read -r file; do
          substituteAllInPlace "$file"
        done

      runHook postPatch
    '';
  } // args);

  init = mkDrv {
    pname = "s6-docker-init";
    inherit (s6-linux-init) version;

    src = builtins.filterSource
      (path: _: builtins.baseNameOf path != "default.nix")
      ./.;

    nativeBuildInputs = [ s6-linux-init ];

    buildPhase = ''
      mkdir -p ./build/etc/${builtins.dirOf s6BaseDir}
      s6-linux-init-maker \
        -NCB \
        -c /run/${s6BaseDir} \
        -p ${lib.makeBinPath runtimeInputs}:/bin \
        -s ${s6ContainerEnv} \
        -f ./skel \
        -- ./build/etc/${s6BaseDir}

      rm ./build/etc/${s6BaseDir}/run-image/s6-linux-init-container-results/exitcode

      mkdir -p ./rootfs/etc/${builtins.dirOf s6MkFifos}
      find ./build -type p \
        | while read -r fifo; do
          printf "%s\n" "/run''${fifo#./build/etc}" >>./rootfs/etc/${s6MkFifos}
          rm -- "$fifo"
        done
    '';

    installPhase = ''
      cp -a ./build/. "$out"
      cp -a ./rootfs/. "$out"

      mkdir -p "$out/bin"
      ln -st "$out/bin" "$out/etc/${s6BaseDir}/bin/"*

      mkdir -p "$out/var"
      ln -s /run "$out/var/run"
    '';
  };

  s6-rc-dir = mkDrv {
    name = "s6-rc-dir";
    src = builtins.path { path = src; name = "src"; };

    nativeBuildInputs = [ s6-rc ];

    sourceRoot = ".";

    buildPhase = ''
      mkdir -p "./build/${builtins.dirOf s6RCDir}"
      s6-rc-compile -v ${builtins.toString verbose} "./build/${s6RCDir}" src
    '';

    installPhase = ''
      cp -a "./build/." "$out/"
    '';
  };
in
symlinkJoin {
  name = "s6-rc-customized";
  paths = [ init s6-rc-dir ] ++ runtimeInputs;
  passthru = { inherit init s6-rc-dir; };
}
