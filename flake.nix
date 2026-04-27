{
  description = "LibrePods release-tracked binary flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-compat.url = "https://flakehub.com/f/edolstra/flake-compat/1.tar.gz";
    systems.url = "github:nix-systems/default";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      flake-parts,
      systems,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import systems;
      imports = [
        inputs.treefmt-nix.flakeModule
      ];

      perSystem =
        {
          pkgs,
          lib,
          ...
        }:
        let
          releaseInfo = builtins.fromJSON (builtins.readFile ./release-info.json);

          runtimeLibs =
            with pkgs;
            [
              dbus
              libpulseaudio
              libGL
              wayland
              libxkbcommon
              vulkan-loader
            ];

          librepodsBinary = pkgs.fetchurl {
            url = releaseInfo.assets.librepods.url;
            hash = releaseInfo.assets.librepods.sha256;
          };

          appImageBinary = pkgs.fetchurl {
            url = releaseInfo.assets.appImage.url;
            hash = releaseInfo.assets.appImage.sha256;
          };

          librepods = pkgs.stdenvNoCC.mkDerivation {
            pname = "librepods";
            version = releaseInfo.release.version;
            dontUnpack = true;

            nativeBuildInputs = with pkgs; [
              makeWrapper
            ];

            installPhase = ''
              install -Dm755 ${librepodsBinary} $out/bin/librepods

              wrapProgram $out/bin/librepods \
                --set-default WINIT_UNIX_BACKEND wayland \
                --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
            '';

            meta = {
              description = "AirPods liberated from Apple's ecosystem";
              homepage = "https://github.com/kavishdevar/librepods";
              license = pkgs.lib.licenses.gpl3Only;
              maintainers = [ "kavishdevar" ];
              platforms = pkgs.lib.platforms.unix;
              mainProgram = "librepods";
            };
          };
        in
        {
          checks = {
            inherit librepods;
          };

          packages = {
            default = librepods;
            librepods = librepods;
            appimage = appImageBinary;
          };

          apps.default = {
            type = "app";
            program = lib.getExe librepods;
            meta.description = "AirPods liberated from Apple's ecosystem";
          };

          devShells.default = pkgs.mkShell {
            name = "librepods-dev";
            buildInputs =
              with pkgs;
              [
                rust-analyzer
                rustc
                cargo
              ]
              ++ runtimeLibs;

            LD_LIBRARY_PATH = lib.makeLibraryPath runtimeLibs;
            WINIT_UNIX_BACKEND = "wayland";
          };

          treefmt = {
            programs.nixfmt.enable = pkgs.lib.meta.availableOn pkgs.stdenv.buildPlatform pkgs.nixfmt;
            programs.nixfmt.package = pkgs.nixfmt;
          };
        };
    };
}
