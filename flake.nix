{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        dotnet = pkgs.dotnetCorePackages.sdk_9_0_3xx;

        godot = pkgs.callPackage ./godot.nix {
          src = ./.;
          version = "4.7.2";
		  stdenv = pkgs.ccacheStdenv;
        };

        mkScons =
          name: extraScript:
          pkgs.writeShellScriptBin name ''
            set -e
            ${pkgs.scons}/bin/scons ccflags="$(pkg-config --cflags x11)" "$@"
            ${extraScript}
          '';

        devPackages = with pkgs; [
          gcc
          python314
          (mkScons "scons" "")
          (mkScons "scons-mono" ''
            godot_bin="$(ls -t bin/godot*.mono 2>/dev/null | head -n1)"
            if [ -z "$godot_bin" ]; then
              echo "No .mono godot binary found in bin/ to generate glue." >&2
              exit 1
            fi
            "$godot_bin" --generate-mono-glue ./modules/mono/glue
            ./modules/mono/build_scripts/build_assemblies.py --godot-output-dir ./bin --push-nupkgs-local "$HOME/.local/share/godot-nupkgs"
          '')
          (writeShellScriptBin "clangd" ''
            exec ${clang-tools}/bin/clangd --query-driver=${gcc}/bin/g++ "$@"
          '')
          clang
          pkg-config
          wayland-scanner
          dotnet
        ];

        x11Libs = with pkgs; [
          libx11
          libxext
          libxrandr
          libxi
          libxinerama
          libxcursor
        ];

        runtimeLibs =
          with pkgs;
          [
            libGL
            libglvnd
            mesa
            wayland
            libdecor
            libxkbcommon
            fontconfig
            pulseaudio
            alsa-lib
            # Vulkan (Forward+/Mobile rendering)
            vulkan-loader
            libxrender

            gcc-unwrapped.lib
          ]
          ++ x11Libs;
        libraryPath = pkgs.lib.makeLibraryPath runtimeLibs;
      in
      {
        packages = {
          default = godot;
          godot = godot;
          godot-mono = godot.override {
            withMono = true;
            nugetDeps = ./deps.json;
          };
        };

        devShells.default = pkgs.mkShell {
          packages = devPackages ++ x11Libs;
          DOTNET_ROOT = "${dotnet}/share/dotnet";
          LD_LIBRARY_PATH = "${libraryPath}:$LD_LIBRARY_PATH";
        };
      }
    );
}
