{
  description = "YAXI extension for MoneyMoney";

  inputs = {
    self.submodules = true;
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        lib = nixpkgs.lib;
        pkgs = nixpkgs.legacyPackages.${system};
        # The linters get a copy with symlinks dereferenced: emmylua_check
        # resolves the symlinked `vendor/json/init.lua` module unreliably.
        src = pkgs.runCommand "yaxi-moneymoney-source" { } ''
          mkdir -p "$out"
          cp -RL ${lib.cleanSource self}/. "$out/"
        '';
      in
      {
        formatter = pkgs.nixfmt-tree;

        packages."bundle" = pkgs.callPackage (
          {
            lib,
            buildNpmPackage,
            versionCheckHook,
            writers,
            # check inputs
            lua5_4,
          }:
          buildNpmPackage {
            pname = "yaxi-moneymoney";
            version = "0.4";
            src = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.unions ([
                ./bundler
                ./yaxi
                ./yaxi.lua
                # tests
                ./.busted
                ./tests
              ]);
            };
            sourceRoot = "source/bundler";
            npmDepsHash = "sha256-ARfsSN/klotb8Ut442tlq7faGeKpB294CCQpLZTL+Bk=";
            nativeBuildInputs = [ versionCheckHook ];
            installPhase = ''
              runHook preInstall

              mkdir "$out"
              cp "YAXI.lua" "$out"
              cp "yaxi-config.json" "$out"

              sha256sum "$out/YAXI.lua" | cut -d' ' -f1 > "$out/YAXI.lua.sha256"

              runHook postInstall
            '';
            doCheck = true;
            nativeCheckInputs = [
              (lua5_4.withPackages (ps: [
                ps.busted
                ps.http
              ]))
            ];
            checkPhase = ''
              runHook preCheck

              pushd ../
              busted --version
              busted --output=TAP --run=offline
              popd

              runHook postCheck
            '';
            doInstallCheck = true;
            versionCheckProgram = writers.writeLua "yaxi-moneymoney-version-check" { } ''
              local manifest = dofile("${./yaxi/manifest.lua}")
              print(manifest.version)
            '';
          }
        ) { };

        packages.default = self.packages.${system}.bundle;

        checks."packages" = pkgs.linkFarmFromDrvs "build-all-packages" (
          lib.attrValues self.packages.${system}
        );

        checks."stylua" = pkgs.runCommand "yaxi-moneymoney-stylua" { } ''
          ${lib.getExe pkgs.stylua} --version
          ${lib.getExe pkgs.stylua} -f ${./stylua.toml} --check ${src}
          touch "$out"
        '';

        checks."emmylua_check" = pkgs.runCommand "yaxi-moneymoney-emmylua_check" { } ''
          ${lib.getExe pkgs.emmylua-check} --version
          ${lib.getExe pkgs.emmylua-check} --warnings-as-errors ${src}
          touch "$out"
        '';

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            emmylua-ls
            emmylua-check
            (lua5_4.withPackages (ps: [
              ps.busted
              ps.http
            ]))
            stylua

            nodejs
          ];
        };
      }
    );
}
