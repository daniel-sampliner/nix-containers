# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ dockerTools
, coreutils
, curl
, execline
, qbittorrent-nox
, writeTextFile
, writeText

, created ? "1970-01-01T00:00:01Z"
}:
let
  name = qbittorrent-nox.pname;

  config = writeText "qBittorrent.conf" ''
    [LegalNotice]
    Accepted=true
  '';

  entrypoint = writeTextFile {
    name = "entrypoint";
    executable = true;
    destination = "/entrypoint";
    text = ''
      #!${execline}/bin/execlineb -Ws1

      importas -D /config XDG_CONFIG_HOME XDG_CONFIG_HOME
      define conf ''${XDG_CONFIG_HOME}/qBittorrent/qBittorrent.conf

      ifelse { eltest -f $conf } { ${coreutils}/bin/stdbuf -oL $1 $@ }
      ifelse
        { ${coreutils}/bin/install -v -Dm0644 ${config} $conf }
        { ${coreutils}/bin/stdbuf -oL $1 $@ }
      foreground
        { fdmove -c 1 2
          ${coreutils}/bin/printf
            "failed to install default config\n" }
        exit 1
    '';
  };
in
dockerTools.streamLayeredImage {
  inherit name created;
  tag = qbittorrent-nox.version;

  maxLayers = 125;

  contents = [
    dockerTools.caCertificates
    coreutils
    entrypoint
    qbittorrent-nox
  ];

  config = {
    Cmd = [ "qbittorrent-nox" ];
    Entrypoint = [ "/entrypoint" ];
    Env = [
      "XDG_CONFIG_HOME=/config"
      "XDG_DATA_HOME=/data"
      "XDG_CACHE_HOME=/cache"
    ];
    ExposedPorts = { "8080/tcp" = { }; };
    Healthcheck = {
      Test = [ "CMD" "${curl}/bin/curl" "-qsS" "localhost:8080/api/v2/app/version" ];
    };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
  };
}
