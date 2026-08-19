{
  lib,
  stdenv,
  buildPackages,
  src,
  version,

  alsa-lib,
  dbus,
  dotnetCorePackages,
  embree,
  enet,
  fontconfig,
  freetype,
  gettext,
  glib,
  glslang,
  graphite2,
  harfbuzz,
  icu,
  installShellFiles,
  libdecor,
  libGL,
  libjpeg_turbo,
  libpulseaudio,
  libtheora,
  libwebp,
  libx11,
  libxcursor,
  libxext,
  libxfixes,
  libxi,
  libxinerama,
  libxkbcommon,
  libxrandr,
  libxrender,
  makeWrapper,
  mbedtls,
  miniupnpc,
  openxr-loader,
  pcre2,
  perl,
  pkg-config,
  recastnavigation,
  scons,
  sdl3,
  speechd-minimal,
  udev,
  vulkan-loader,
  wayland,
  wayland-scanner,
  wslay,
  zstd,

  nugetDeps ? null,

  withAlsa ? stdenv.hostPlatform.isLinux,
  withDbus ? true,
  withFontconfig ? true,
  withMono ? false,
  withBuiltins ? !stdenv.hostPlatform.isLinux,
  withPrecision ? "single",
  withPulseaudio ? true,
  withSpeechd ? true,
  withTouch ? true,
  withUdev ? stdenv.hostPlatform.isLinux,
  # Wayland in Godot requires X11 until upstream fix is merged
  # https://github.com/godotengine/godot/pull/73504
  withWayland ? stdenv.hostPlatform.isLinux,
  withX11 ? stdenv.hostPlatform.isLinux,
}:
assert lib.asserts.assertOneOf "withPrecision" withPrecision [
  "single"
  "double"
];
let
  mkSconsFlagsFromAttrSet = lib.mapAttrsToList (
    k: v: if builtins.isString v then "${k}=${v}" else "${k}=${builtins.toJSON v}"
  );

  arch = stdenv.hostPlatform.linuxArch;
  suffix = lib.optionalString withMono "-mono";

  binary = lib.concatStringsSep "." (
    [
      "godot"
      "linuxbsd"
      "editor"
    ]
    ++ lib.optional (withPrecision != "single") withPrecision
    ++ [ arch ]
    ++ lib.optional withMono "mono"
  );

  dotnet-sdk = if withMono then dotnetCorePackages.sdk_8_0-source else null;

  dotnetRoot = if withMono then "${dotnet-sdk}/share/dotnet" else null;

  harfbuzz-raster = harfbuzz.override {
    withRaster = lib.versionAtLeast version "4.7";
    withCairo = lib.versionAtLeast version "4.7";
  };
  harfbuzz-icu = harfbuzz-raster.override {
    withIcu = true;
    harfbuzz = harfbuzz-raster;
  };

  attrs = finalAttrs: {
    __structuredAttrs = true;

    pname = "godot${suffix}";
    inherit version src;

    outputs = [ "out" ];
    separateDebugInfo = true;

    env = {
      # Shown in the editor's About dialog / Engine.get_version_info().build.
      BUILD_NAME = "nix-custom";
    };

    preConfigure = lib.optionalString withMono ''
      dotnet sln modules/mono/editor/GodotTools/GodotTools.sln \
        remove modules/mono/editor/GodotTools/GodotTools.OpenVisualStudio/GodotTools.OpenVisualStudio.csproj

      dotnet restore modules/mono/glue/GodotSharp/GodotSharp.sln
      dotnet restore modules/mono/editor/GodotTools/GodotTools.sln
      dotnet restore modules/mono/editor/Godot.NET.Sdk/Godot.NET.Sdk.sln
    '';

    # Godot 4.7 with system HarfBuzz needs explicit raster linkage.
    # See https://github.com/godotengine/godot/pull/120568
    preBuild = lib.optionalString (!withBuiltins && lib.versionAtLeast version "4.7") ''
      export NIX_LDFLAGS="$NIX_LDFLAGS -lharfbuzz-raster"
    '';

    # From: https://github.com/godotengine/godot/blob/master/SConstruct
    sconsFlags = mkSconsFlagsFromAttrSet (
      {
        precision = withPrecision;
        production = true;
        platform = "linuxbsd";
        target = "editor";
        debug_symbols = true;

        # Options from 'platform/linuxbsd/detect.py'
        alsa = withAlsa;
        dbus = withDbus;
        fontconfig = withFontconfig;
        pulseaudio = withPulseaudio;
        speechd = withSpeechd;
        touch = withTouch;
        udev = withUdev;
        wayland = withWayland;
        x11 = withX11;

        module_mono_enabled = withMono;

        # aliasing bugs exist with hardening+LTO
        # https://github.com/godotengine/godot/pull/104501
        ccflags = "-fno-strict-aliasing";
        linkflags = "-Wl,--build-id";

        builtin_msdfgen = true;
        builtin_rvo2_2d = true;
        builtin_rvo2_3d = true;
        builtin_xatlas = true;
        builtin_clipper2 = true;

        use_sowrap = false;
      }
      // lib.optionalAttrs (lib.versionAtLeast version "4.5") {
        redirect_build_objects = false;
      }
    );

    enableParallelBuilding = true;
    strictDeps = true;

    depsBuildBuild = lib.optionals (stdenv.buildPlatform != stdenv.hostPlatform) [
      buildPackages.stdenv.cc
      pkg-config
    ];

    postPatch = ''
      # stop scons from hiding NIX_CFLAGS_COMPILE / NIX_LDFLAGS etc. from the compiler
      perl -pi -e '{ $r += s:(env = Environment\(.*):\1\nenv["ENV"] = os.environ: } END { exit ($r != 1) }' SConstruct
    ''
    + lib.optionalString (!withBuiltins) ''
      # disable all builtin_* libs by default; the forced-true ones above win back
      perl -pi -e '{ $r |= s:(opts.Add\(BoolVariable\("builtin_.*, )True(\)\)):\1False\2: } END { exit ($r != 1) }' SConstruct
    ''
    + lib.optionalString (libGL != null) ''
      substituteInPlace thirdparty/glad/egl.c \
        --replace-fail \
          'static const char *NAMES[] = {"libEGL.so.1", "libEGL.so"}' \
          'static const char *NAMES[] = {"${lib.getLib libGL}/lib/libEGL.so"}'

      substituteInPlace thirdparty/glad/gl.c \
        --replace-fail \
          'static const char *NAMES[] = {"libGLESv2.so.2", "libGLESv2.so"}' \
          'static const char *NAMES[] = {"${lib.getLib libGL}/lib/libGLESv2.so"}'

      substituteInPlace thirdparty/glad/gl{,x}.c \
        --replace-fail \
          '"libGL.so.1"' \
          '"${lib.getLib libGL}/lib/libGL.so"'
    ''
    + ''
      substituteInPlace thirdparty/volk/volk.c \
        --replace-fail \
          'dlopen("libvulkan.so.1"' \
          'dlopen("${lib.getLib vulkan-loader}/lib/libvulkan.so"'
    '';

    buildInputs =
      lib.optionals (!withBuiltins) (
        [
          embree
          enet
          freetype
          glslang
          graphite2
          harfbuzz-icu
          icu
          libtheora
          libwebp
          mbedtls
          miniupnpc
          openxr-loader
          pcre2
          recastnavigation
          wslay
          zstd
        ]
        ++ lib.optionals (lib.versionAtLeast version "4.5") [
          libjpeg_turbo
          sdl3
        ]
      )
      ++ lib.optionals withMono dotnet-sdk.packages
      ++ lib.optional withAlsa alsa-lib
      ++ lib.optional (withX11 || withWayland) libxkbcommon
      ++ lib.optionals withX11 [
        libx11
        libxcursor
        libxext
        libxfixes
        libxi
        libxinerama
        libxrandr
        libxrender
      ]
      ++ lib.optionals withWayland [
        libdecor
        wayland
      ]
      ++ lib.optional withDbus dbus
      ++ lib.optional withFontconfig fontconfig
      ++ lib.optional withPulseaudio libpulseaudio
      ++ lib.optionals withSpeechd [
        speechd-minimal
        glib
      ]
      ++ lib.optional withUdev udev;

    nativeBuildInputs = [
      gettext
      installShellFiles
      perl
      pkg-config
      scons
    ]
    ++ lib.optionals withWayland [ wayland-scanner ]
    ++ lib.optionals withMono [
      makeWrapper
      dotnet-sdk
    ];

    postBuild = lib.optionalString withMono ''
      echo "Generating Glue"
      bin/${binary} --headless --generate-mono-glue modules/mono/glue
      echo "Building C#/.NET Assemblies"
      python modules/mono/build_scripts/build_assemblies.py --godot-output-dir bin --precision=${withPrecision}
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"/{bin,libexec}
      cp -r bin/${binary} "$out"/libexec/
      ln -s ../libexec/${binary} "$out"/bin/godot${suffix}

      installManPage misc/dist/linux/godot.6

      mkdir -p "$out"/share/{applications,icons/hicolor/scalable/apps}
      cp misc/dist/linux/org.godotengine.Godot.desktop \
        "$out/share/applications/org.godotengine.Godot${suffix}.desktop"
      substituteInPlace "$out/share/applications/org.godotengine.Godot${suffix}.desktop" \
        --replace-fail "Exec=godot" "Exec=$out/bin/godot${suffix}" \
        --replace-fail "Godot Engine" "Godot Engine (${version}${lib.optionalString withMono ", Mono"})"
      cp misc/logo/icon.svg "$out/share/icons/hicolor/scalable/apps/godot.svg"
      cp misc/logo/icon.png "$out/share/icons/godot.png"
    ''
    + lib.optionalString withMono ''
      cp -r bin/GodotSharp "$out"/libexec/
      mkdir -p "$out"/share/nuget
      mv "$out"/libexec/GodotSharp/Tools/nupkgs "$out"/share/nuget/source

      wrapProgram "$out"/libexec/${binary} \
        --prefix NUGET_FALLBACK_PACKAGES ';' "$out"/share/nuget/packages/ \
        --set DOTNET_ROOT "${dotnetRoot}"
    ''
    + ''
      runHook postInstall
    '';

    meta = {
      description = "Custom Godot build";
      homepage = "https://godotengine.org";
      license = lib.licenses.mit;
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      mainProgram = "godot${suffix}";
    };
  };

  unwrapped = stdenv.mkDerivation (
    if withMono && nugetDeps != null then
      dotnetCorePackages.addNuGetDeps {
        inherit nugetDeps;
        overrideFetchAttrs = old: rec {
          runtimeIds = map (system: dotnetCorePackages.systemToDotnetRid system) old.meta.platforms;
          buildInputs =
            old.buildInputs
            ++ lib.concatLists (lib.attrValues (lib.getAttrs runtimeIds dotnet-sdk.targetPackages));
        };
      } attrs
    else
      attrs
  );

  wrapper =
    if withMono then
      stdenv.mkDerivation (finalAttrs: {
        __structuredAttrs = true;

        pname = finalAttrs.unwrapped.pname + "-wrapper";
        inherit (finalAttrs.unwrapped) version outputs meta;
        inherit unwrapped dotnet-sdk;

        dontUnpack = true;
        dontConfigure = true;
        dontBuild = true;

        nativeBuildInputs = [ makeWrapper ];
        strictDeps = true;

        installPhase = ''
          runHook preInstall

          mkdir -p "$out"/{bin,libexec,share/applications,nix-support}
          cp -d "$unwrapped"/bin/* "$out"/bin/
          ln -s "$unwrapped"/libexec/* "$out"/libexec/
          ln -s "$unwrapped"/share/nuget "$out"/share/
          cp "$unwrapped/share/applications/org.godotengine.Godot${suffix}.desktop" \
            "$out/share/applications/org.godotengine.Godot${suffix}.desktop"

          substituteInPlace "$out/share/applications/org.godotengine.Godot${suffix}.desktop" \
            --replace-fail "Exec=$unwrapped/bin/godot${suffix}" "Exec=$out/bin/godot${suffix}"
          ln -s "$unwrapped"/share/icons "$out"/share/
          ln -s "$unwrapped"/share/man "$out"/share/

          # ensure dotnet hooks get run
          echo "${finalAttrs.dotnet-sdk}" >> "$out"/nix-support/propagated-build-inputs

          wrapProgram "$out"/libexec/${binary} \
            --prefix PATH : "${lib.makeBinPath [ finalAttrs.dotnet-sdk ]}" \
            --set DOTNET_ROOT "${finalAttrs.dotnet-sdk}/share/dotnet"

          runHook postInstall
        '';

        postFixup = lib.concatMapStringsSep "\n" (output: ''
          [[ -e "''$${output}" ]] || ln -s "${unwrapped.${output}}" "''$${output}"
        '') finalAttrs.unwrapped.outputs;

        passthru = unwrapped.passthru or { };
      })
    else
      unwrapped;
in
wrapper
