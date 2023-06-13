# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, execline
, coreutils
, gosu
, komga
, shadow
, writeTextFile

, created ? "1970-01-01T00:00:01Z"
}:
let
  name = komga.pname;

  entrypoint = writeTextFile {
    name = "entrypoint";
    executable = true;
    destination = "/entrypoint";
    text = ''
      #!${execline}/bin/execlineb -Ws1

      importas -D /config KOMGA_CONFIGDIR KOMGA_CONFIGDIR
      importas -D 911 PUID PUID
      importas -D 911 PGID PGID

      if { ${shadow}/bin/groupadd --gid $PGID ${name} }
      if { ${shadow}/bin/useradd
        --home-dir /var/empty
        --no-create-home
        --shell /bin/false
        --uid $PUID
        ${name}
      }
      if { ${coreutils}/bin/mkdir -p $KOMGA_CONFIGDIR }
      if { ${coreutils}/bin/chown -R ''${PUID}:''${PGID} $KOMGA_CONFIGDIR }
      ${gosu}/bin/gosu ''${PUID}:''${PGID} $1 $@
    '';
  };
in
dockerTools.streamLayeredImage {
  inherit name created;
  tag = komga.version;

  maxLayers = 125;

  contents = [ entrypoint komga ];

  config = {
    Cmd = [ "/bin/komga" ];
    Entrypoint = [ "/entrypoint" ];
    Env = [
      "KOMGA_CONFIGDIR=/config"
      "JAVA_TOOL_OPTIONS=\"-XX:MaxRAMPercentage=75\""
    ];
    ExposedPorts = { "8080/tcp" = { }; };
    Labels = {
      "org.opencontainers.image.source" = "https://github.com/daniel-sampliner/nix-containers";
    };
  };

  passthru = { inherit entrypoint; };
}
