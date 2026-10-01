{
  description = "A headless Nintendo Entertainment System core in Common Lisp.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The org flake preset. This one `mkPackageFlake` call generates the
    # entire required-output table (packages, checks.default,
    # checks.formatting, checks.docs, apps.test, apps.default, devShells,
    # formatter, overlays.default) so none of it drifts from the other
    # nerima-lisp repositories. See PACKAGE_STANDARD.md, "flake.nix の書き方".
    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.6.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Test-only (L0): only cl-nes/test loads it. Pulled through
    # lispCheckDependencies below, never lispDependencies.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Runtime dependency (L1, depth 0): cartridge ROM file reads
    # (host-kit:read-file-octets). See cl-nes.asd's :depends-on comment and
    # DEPENDENCY_POLICY.md's 3-checkpoint record for why this repository no
    # longer claims to be dependency-free.
    cl-host-kit = {
      url = "github:nerima-lisp/cl-host-kit/v0.3.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cl-glfw3-kit = {
      url = "github:nerima-lisp/cl-glfw3-kit/v0.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cl-cli = {
      url = "github:nerima-lisp/cl-cli/v1.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Dev-time only (outside the dependency layers entirely): structural
    # refactoring input for `paredit inspect check`, never linked into the
    # Lisp image.
    paredit-cli = {
      url = "github:nerima-lisp/paredit-cli/v1.6.3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nes-test-roms = {
      url = "github:christopherpow/nes-test-roms/95d8f621ae55cee0d09b91519a8989ae0e64753b";
      flake = false;
    };

    accuracy-coin = {
      url = "github:100thCoin/AccuracyCoin/673ef550db296136d52229961e7d39366116882a";
      flake = false;
    };

    retrobrews-nes-games = {
      url = "https://github.com/retrobrews/nes-games/archive/d20061bf9917e8bb8b947d4dba8c59372f5762a0.tar.gz";
      flake = false;
    };

    goro-nes-homebrew = {
      url = "https://github.com/GOROman/calude-famicom-game/archive/576a0c249d017e4d339410a2c19739d31778ec6b.tar.gz";
      flake = false;
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-nix-forge,
      cl-weave,
      cl-host-kit,
      cl-cli,
      cl-glfw3-kit,
      paredit-cli,
      nes-test-roms,
      accuracy-coin,
      retrobrews-nes-games,
      goro-nes-homebrew,
      treefmt-nix,
      ...
    }:
    let
      # x86_64-linux is what CI would gate; aarch64-darwin is the
      # development machine this repository is actually built on today.
      # cl-host-kit's own flake.nix (the immediately adjacent, most
      # recently migrated sibling) reverted a Linux-only `systems` the day
      # after trying it, for exactly this reason -- see its flake.nix
      # comment. aarch64-linux is neither, so it is left out; it was never
      # covered by this repository's own former three-system list in any
      # way this project's tooling could verify.
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      testTimeoutSeconds = 300;
      coverageTimeoutSeconds = 600;
      benchmarkTimeoutSeconds = 120;
      timeoutGraceSeconds = 15;

      frontendExecutable =
        ctx:
        let
          glfw = cl-glfw3-kit.packages.${ctx.system}.cl-glfw3-kit;
          cli = cl-cli.packages.${ctx.system}.cl-cli;
          sdl2 = ctx.pkgs.SDL2;
          sharedLibrary = ctx.pkgs.stdenv.hostPlatform.extensions.sharedLibrary;
          glfwLibrary = "${ctx.pkgs.glfw}/lib/libglfw${sharedLibrary}";
          sdl2Library =
            if ctx.pkgs.stdenv.hostPlatform.isDarwin then
              "${sdl2}/lib/libSDL2-2.0.0.dylib"
            else
              "${sdl2}/lib/libSDL2-2.0.so";
        in
        ctx.cl.mkExecutable {
          programPath = "frontend/cl-nes";
          args = ctx.lispDerivationArgs // {
            pname = "cl-nes";
            lispSystem = "cl-nes/frontend";
            lispDependencies = [
              ctx.package
              cli
              glfw
            ];
            nativeLibraries = [
              ctx.pkgs.glfw
              sdl2
            ];
            env = {
              CL_GLFW3_KIT_LIBRARY = glfwLibrary;
              CL_NES_SDL2_LIBRARY = sdl2Library;
            };
          };
        };
    in
    cl-nix-forge.lib.${builtins.head systems}.mkPackageFlake {
      inherit self systems nixpkgs;

      pname = "cl-nes";
      asd = ./cl-nes.asd;
      root = ./.;

      meta = {
        description = "A headless Nintendo Entertainment System core in Common Lisp.";
        homepage = "https://github.com/nerima-lisp/cl-nes";
        license = nixpkgs.lib.licenses.mit;
        platforms = nixpkgs.lib.platforms.unix;
      };

      lispDependencies = ctx: [ cl-host-kit.packages.${ctx.system}.cl-host-kit ];
      lispCheckDependencies = ctx: [
        cl-weave.packages.${ctx.system}.cl-weave
        cl-cli.packages.${ctx.system}.cl-cli
        cl-glfw3-kit.packages.${ctx.system}.cl-glfw3-kit
      ];

      runner = "run-tests.lisp";
      timeoutSeconds = testTimeoutSeconds;
      killAfterSeconds = timeoutGraceSeconds;

      docs.root = ./docs;

      treefmt.evalModule = treefmt-nix.lib.evalModule;

      extraOutputs =
        ctx:
        let
          pkgs = ctx.pkgs;
          paredit = paredit-cli.packages.${ctx.system}.default or null;
          littleThings = pkgs.runCommand "cl-nes-little-things-roms"
            {
              nativeBuildInputs = [ pkgs.unzip ];
              src = pkgs.fetchurl {
                url = "https://github.com/pinobatch/little-things-nes/releases/download/v20.10/little-things-nes-20.10.zip";
                hash = "sha256-V0Ko8iDvC6/SzZ7UNsSl+qnxe7JbCKb8JgAaPNMWeb4=";
              };
            }
            ''
              mkdir -p "$out"
              unzip -q "$src" -d "$out"
            '';
          holyMapperel = pkgs.runCommand "cl-nes-holy-mapperel-roms"
            {
              nativeBuildInputs = [ pkgs.p7zip ];
              src = pkgs.fetchurl {
                url = "https://github.com/pinobatch/holy-mapperel/releases/download/v0.02/holy-mapperel-bin-0.02.7z";
                hash = "sha256-cPhWceIfKTWZuuu2YvrrBqTATpyc6yg9ltQZfwnkzno=";
              };
            }
            ''
              mkdir -p "$out"
              7z x "$src" -o"$out" >/dev/null
            '';
        in
        {
          checks = {
            # run-coverage.lisp asserts its own measured 96.22%/92.22% floor and errors
            # (non-zero exit) below it, so this check needs no separate
            # threshold script -- unlike cl-host-kit, which scrapes raw
            # sb-cover HTML because its run-coverage.lisp has no such
            # in-Lisp gate.
            coverage = ctx.cl.mkScriptCheck {
              drv = ctx.package;
              entryPoint = "run-coverage.lisp";
              name = "cl-nes-coverage";
              timeoutSeconds = coverageTimeoutSeconds;
              killAfterSeconds = timeoutGraceSeconds;
            };
            frontend =
              (ctx.cl.mkScriptCheck {
                drv = ctx.package;
                entryPoint = "run-frontend-tests.lisp";
                name = "cl-nes-frontend-test";
                timeoutSeconds = testTimeoutSeconds;
                killAfterSeconds = timeoutGraceSeconds;
              }).overrideAttrs
                (old: {
                  env = (old.env or { }) // {
                    CL_GLFW3_KIT_LIBRARY = "${pkgs.glfw}/lib/libglfw${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}";
                    CL_NES_SDL2_LIBRARY =
                      if pkgs.stdenv.hostPlatform.isDarwin then
                        "${pkgs.SDL2}/lib/libSDL2-2.0.0.dylib"
                      else
                        "${pkgs.SDL2}/lib/libSDL2-2.0.so";
                  };
                });
            rom-suite =
              (ctx.cl.mkScriptCheck {
                drv = ctx.package;
                entryPoint = "run-rom-suite.lisp";
                name = "cl-nes-rom-suite";
                timeoutSeconds = 600;
                killAfterSeconds = timeoutGraceSeconds;
              }).overrideAttrs
                (old: {
                  env = (old.env or { }) // {
                    CL_NES_TEST_ROMS = "${nes-test-roms}";
                    CL_NES_ACCURACY_COIN = "${accuracy-coin}/AccuracyCoin.nes";
                    CL_NES_NESTEST_ROM = "${nes-test-roms}/other/nestest.nes";
                    CL_NES_NESTEST_LOG = "${nes-test-roms}/other/nestest.log";
                  };
                });
            compat =
              (ctx.cl.mkScriptCheck {
                drv = ctx.package;
                entryPoint = "run-compat.lisp";
                name = "cl-nes-compat";
                timeoutSeconds = 1800;
                killAfterSeconds = timeoutGraceSeconds;
              }).overrideAttrs
                (old: {
                  env = (old.env or { }) // {
                    CL_NES_COMPAT_ROOT = "${retrobrews-nes-games}";
                    CL_NES_COMPAT_ROOT_GORO = "${goro-nes-homebrew}/roms";
                    CL_NES_COMPAT_ROOT_LITTLE = "${littleThings}";
                    CL_NES_COMPAT_ROOT_HOLY = "${holyMapperel}";
                    CL_NES_COMPAT_ARTIFACTS = "compat-artifacts";
                    CL_NES_COMPAT_FRAMES = "1800";
                  };
                });
          }
          // pkgs.lib.optionalAttrs (paredit != null) {
            paredit =
              pkgs.runCommand "cl-nes-paredit"
                {
                  nativeBuildInputs = [ paredit ];
                  src = ./.;
                }
                ''
                  cd "$src"
                  find src t frontend -type f -name '*.lisp' -print | while read -r file; do
                    paredit inspect check --file "$file" --timeout-ms 30000
                  done
                  for file in run-*.lisp benchmark/*.lisp; do
                    paredit inspect check --file "$file" --timeout-ms 30000
                  done
                  touch "$out"
                '';
          };

          apps.bench = ctx.cl.mkTestApp {
            pname = "cl-nes-bench";
            runner = "benchmark/run-benchmarks.lisp";
            timeoutSeconds = benchmarkTimeoutSeconds;
            killAfterSeconds = timeoutGraceSeconds;
            src = ctx.src;
            lisp = ctx.lispDerivationArgs.lisp;
            lispDependencies = ctx.lispDerivationArgs.lispDependencies;
          };
        };

      overrideOutputs =
        ctx:
        let
          frontend = frontendExecutable ctx;
        in
        {
          packages.default = frontend;
          apps.default = ctx.cl.mkApp { drv = frontend; };
        };
    };
}
