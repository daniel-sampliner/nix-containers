# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, execline
, gosu
, qbittorrent-nox
, shadow
, writeTextFile

, created ? "1970-01-01T00:00:01Z"
}:
let
  name = qbittorrent-nox.pname;

  entrypoint = writeTextFile {
    name = "entrypoint";
    executable = true;
    destination = "/entrypoint";
    text = ''
      #!${execline}/bin/execlineb -Ws1

      importas -D /config XDG_CONFIG_HOME XDG_CONFIG_HOME
      importas -D /config XDG_DATA_HOME XDG_DATA_HOME
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
      if { ${coreutils}/bin/mkdir -p $XDG_CONFIG_HOME $XDG_DATA_HOME }
      if { ${coreutils}/bin/chown -R ''${PUID}:''${PGID} $XDG_CONFIG_HOME $XDG_DATA_HOME }
      ${gosu}/bin/gosu ''${PUID}:''${PGID} $1 $@
    '';
  };
in
dockerTools.streamLayeredImage {
  inherit name created;
  tag = qbittorrent-nox.version;

  maxLayers = 125;

  contents = [ entrypoint qbittorrent-nox ];

  config = {
    Cmd = [ "/bin/komga" ];
    Entrypoint = [ "/entrypoint" ];
    Env = [
      "XDG_CONFIG_HOME=/config"
      "XDG_DATA_HOME=/config"
    ];
    Labels = {
      "org.opencontainers.image.source" = "https://github.com/becometheteapot/nix-containers";
    };
  };
}
