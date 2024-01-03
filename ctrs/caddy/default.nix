# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

{ lib
, buildGoModule
, caddy
, curl
, dockerTools
, mailcap
, runCommand
, writeText
}:
let
  name = caddy.pname;

  caddy-w-plugins =
    let
      modules = [ "github.com/caddy-dns/cloudflare" ];
      modulesFile = writeText "modules" (lib.concatMapStrings
        (m: "_ \"${m}\"\n")
        [ "github.com/caddy-dns/cloudflare" ]);
      src = runCommand "src-patched" { } ''
        cp -a ${caddy.src} $out
        chmod -R u+w $out
        sed -i -E \
          '\:^[[:blank:]]+// plug in Caddy modules here$:r ${modulesFile}' \
          $out/cmd/caddy/main.go
        ${caddy.go}/bin/gofmt -w $out/cmd/caddy/main.go
      '';
    in
    caddy.override {
      buildGoModule = args: buildGoModule (args // {
        inherit src;
        overrideModAttrs = old: {
          preBuild = old.preBuild or "" + ''
            go get ${lib.escapeShellArgs modules}
          '';

          postInstall = old.postInstall or "" + ''
            install -Dm0644 -t "$out/smuggle" go.mod go.sum
          '';
        };
        postConfigure = caddy.postConfigure or "" + ''
          cp vendor/smuggle/go.{mod,sum} .
        '';
        vendorHash = "sha256-eg3FyiEtrRpWax6FQCLM9ZgaapmU7ntCoBgBRm100i8=";
      });
    };
in
dockerTools.streamLayeredImage {
  inherit name;
  tag = caddy.version;


  contents = [
    caddy-w-plugins
    curl
    dockerTools.caCertificates
    mailcap
  ];

  config = {
    Entrypoint = [ "caddy" ];
    Cmd = [
      "run"
      "--config"
      "/etc/caddy/Caddyfile"
      "--adapter"
      "caddyfile"
    ];

    Env = [
      "CADDY_VERSION=${caddy-w-plugins.version}"
      "XDG_CONFIG_HOME=/config"
      "XDG_DATA_HOME=/data"
    ];
    ExposedPorts = {
      "80/tcp" = { };
      "443/tcp" = { };
      "443/udp" = { };
      "2019/tcp" = { };
    };
    Labels = {
      "org.opencontainers.image.source" =
        "https://github.com/becometheteapot/${name}";
    };
    WorkingDir = "/srv";
  };

  passthru = { inherit caddy-w-plugins; };
}
