{
  description = "A production-oriented, headless Nintendo Entertainment System core in Common Lisp.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.3.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    paredit-cli = {
      url = "github:nerima-lisp/paredit-cli/v1.6.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      cl-weave,
      paredit-cli,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      checkTimeout = "120s";
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          docs = pkgs.python3.withPackages (
            pythonPackages: with pythonPackages; [
              mkdocs
              mkdocs-material
              pymdown-extensions
            ]
          );
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.sbcl
              pkgs.coreutils
              pkgs.jq
              pkgs.perl
              docs
            ]
            ++
              pkgs.lib.optional (builtins.hasAttr system paredit-cli.packages)
                paredit-cli.packages.${system}.default;
            shellHook = ''
              export CL_SOURCE_REGISTRY="(:source-registry (:tree \"$PWD\") (:tree \"${cl-weave.outPath}\") :ignore-inherited-configuration)"
            '';
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          docs = pkgs.python3.withPackages (
            pythonPackages: with pythonPackages; [
              mkdocs
              mkdocs-material
              pymdown-extensions
            ]
          );
        in
        {
          cl-nes =
            pkgs.runCommand "cl-nes-checks"
              {
                nativeBuildInputs = [
                  pkgs.sbcl
                  pkgs.coreutils
                  docs
                ]
                ++
                  pkgs.lib.optional (builtins.hasAttr system paredit-cli.packages)
                    paredit-cli.packages.${system}.default;
                src = ./.;
              }
              ''
                set -eu
                cp -r "$src" project
                chmod -R u+w project
                export HOME="$TMPDIR/home"
                export XDG_CACHE_HOME="$TMPDIR/cache"
                mkdir -p "$HOME" "$XDG_CACHE_HOME"
                cd project
                export CL_SOURCE_REGISTRY="(:source-registry (:tree \"$PWD\") (:tree \"${cl-weave.outPath}\") :ignore-inherited-configuration)"
                if command -v paredit >/dev/null 2>&1; then
                  for file in src/*.lisp t/*.lisp run-*.lisp; do
                    paredit inspect check --file "$file" --timeout-ms 30000
                  done
                else
                  echo "warning: paredit-cli is unavailable for ${system}; syntax check skipped" >&2
                fi
                ${pkgs.coreutils}/bin/timeout --signal=TERM --kill-after=10s ${checkTimeout} ${pkgs.sbcl}/bin/sbcl --noinform --non-interactive --eval '(require :asdf)' --load cl-nes.asd --eval '(asdf:compile-system "cl-nes" :force t)' --quit
                ${pkgs.coreutils}/bin/timeout --signal=TERM --kill-after=10s ${checkTimeout} ${pkgs.sbcl}/bin/sbcl --noinform --non-interactive --load run-tests.lisp --quit
                ${pkgs.coreutils}/bin/timeout --signal=TERM --kill-after=10s ${checkTimeout} ${pkgs.sbcl}/bin/sbcl --noinform --non-interactive --load run-coverage.lisp --quit
                ${pkgs.coreutils}/bin/timeout --signal=TERM --kill-after=10s ${checkTimeout} mkdocs build --strict --config-file docs/mkdocs.yml --site-dir "$TMPDIR/site"
                mkdir -p "$out/coverage"
                cp coverage/coverage-summary.txt "$out/coverage/"
                cp -r coverage/html "$out/coverage/"
              '';
        }
      );

      formatter = forAllSystems (system: (import nixpkgs { inherit system; }).nixfmt);
    };
}
