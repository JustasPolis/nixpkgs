{ lib
, stdenv
, callPackage
, fetchurl

, jdk
, zlib
, python3
, lldb
, dotnet-sdk_7
, maven
, openssl
, expat
, libxcrypt
, libxcrypt-legacy
, fontconfig
, libxml2
, runCommand
, musl
, R
, libgcc
, lttng-ust_2_12
, xz
, xorg
, wayland
, libGL

, vmopts ? null
}:

let
  inherit (stdenv.hostPlatform) system;

  # `ides.json` is handwritten and contains information that doesn't change across updates, like maintainers and other metadata
  # `versions.json` contains everything generated/needed by the update script version numbers, build numbers and tarball hashes
  ideInfo = lib.importJSON ./bin/ides.json;
  versions = lib.importJSON ./bin/versions.json;
  products = versions.${system} or (throw "Unsupported system: ${system}");

  package = if stdenv.isDarwin then ./bin/darwin.nix else ./bin/linux.nix;
  mkJetBrainsProductCore = callPackage package { inherit vmopts; };
  mkMeta = meta: fromSource: {
    inherit (meta) homepage longDescription;
    description = meta.description + lib.optionalString meta.isOpenSource (if fromSource then " (built from source)" else " (patched binaries from jetbrains)");
    maintainers = map (x: lib.maintainers."${x}") meta.maintainers;
    license = if meta.isOpenSource then lib.licenses.asl20 else lib.licenses.unfree;
  };

  mkJetBrainsProduct =
    { pname
    , fromSource ? false
    , extraWrapperArgs ? [ ]
    , extraLdPath ? [ ]
    , extraBuildInputs ? [ ]
    }:
    mkJetBrainsProductCore {
      inherit pname jdk extraWrapperArgs extraLdPath extraBuildInputs;
      src = if fromSource then communitySources."${pname}" else
      fetchurl {
        url = products."${pname}".url;
        sha256 = products."${pname}".sha256;
      };
      inherit (products."${pname}") version;
      buildNumber = products."${pname}".build_number;
      inherit (ideInfo."${pname}") wmClass product;
      productShort = ideInfo."${pname}".productShort or ideInfo."${pname}".product;
      meta = mkMeta ideInfo."${pname}".meta fromSource;
      libdbm = if ideInfo."${pname}".meta.isOpenSource then communitySources."${pname}".libdbm else communitySources.idea-community.libdbm;
      fsnotifier = if ideInfo."${pname}".meta.isOpenSource then communitySources."${pname}".fsnotifier else communitySources.idea-community.fsnotifier;
    };

  communitySources = callPackage ./source { };

  buildIdea = args:
    mkJetBrainsProduct (args // {
      extraLdPath = [ zlib ];
      extraWrapperArgs = [
        ''--set M2_HOME "${maven}/maven"''
        ''--set M2 "${maven}/maven/bin"''
      ];
    });

  buildPycharm = args:
    (mkJetBrainsProduct args).overrideAttrs (finalAttrs: previousAttrs: lib.optionalAttrs stdenv.isLinux {
      buildInputs = with python3.pkgs; (previousAttrs.buildInputs or []) ++ [ python3 setuptools ];
      preInstall = ''
        echo "compiling cython debug speedups"
        if [[ -d plugins/python-ce ]]; then
            ${python3.interpreter} plugins/python-ce/helpers/pydev/setup_cython.py build_ext --inplace
        else
            ${python3.interpreter} plugins/python/helpers/pydev/setup_cython.py build_ext --inplace
        fi
      '';
      # See https://www.jetbrains.com/help/pycharm/2022.1/cython-speedups.html
    });

in
rec {
  # Sorted alphabetically
  idea-community-bin = buildIdea { pname = "idea-community"; extraBuildInputs = [ stdenv.cc.cc lldb musl ]; };

  plugins = callPackage ./plugins { } // { __attrsFailEvaluation = true; };

}
