{
  description = "dotzsh - A Nix flake for managing zsh configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # flake-schemas.url = "https://flakehub.com/f/DeterminateSystems/flake-schemas/*";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # 定义 dotzsh 包
        dotzsh-package = pkgs.stdenv.mkDerivation {
          name = "dotzsh";
          version = "0.0.1";
          src = ./.;
          buildInputs = [ pkgs.bash ];

          buildPhase = ''
            mkdir -p $out/bin
            cp -ar ./ $out/bin/
          '';

          installPhase = ''
            chmod +x $out/bin/common.sh.in
          '';

          postInstall = ''
            if [ ! -f "$out/bin/common.sh.in" ]; then
              echo "Error: common.sh.in not found"
              exit 1
            fi
          '';
        };

        # Home Manager Module
        hmModule = { config, pkgs, lib, ... }:
          let
            cfg = config.programs.dotzsh;
          in
          {
            options.programs.dotzsh = {
              enable = lib.mkEnableOption "dotzsh";
              runOnInit = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether to run the script on shell initialization";
              };
            };

            config = lib.mkIf cfg.enable {
              home.packages = [ cfg.package ];
              programs.zsh.initExtra = lib.mkIf cfg.runOnInit ''
                if [ command -v bash >/dev/null 2>&1 ]; then
                  ${pkgs.bash}/bin/bash ${cfg.package}/bin/common.sh.in 1
                fi
              '';
            };
          };

        # NixOS Module
        nixosModule = { config, pkgs, lib, ... }:
          let
            cfg = config.programs.dotzsh;
          in
          {
            options.programs.dotzsh = {
              enable = lib.mkEnableOption "dotzsh";
              runOnInit = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether to run the script on shell initialization";
              };
            };

            config = lib.mkIf cfg.enable {
              users.users = lib.mapAttrs (_: userConfig:
                if userConfig.shell == "/run/current-system/sw/bin/zsh" then
                  {
                    shellInit = lib.mkIf cfg.runOnInit ''
                      ${pkgs.bash}/bin/bash ${dotzsh-package}/bin/common.sh.in 1
                    '';
                  }
                else
                  {}
              ) config.users.users;
            };
          };

      in
      {
        # packages.dotzsh-package = dotzsh-package;
        packages = {
          default = dotzsh-package;
          inherit dotzsh-package;

          run-dotzsh-init = pkgs.writeScriptBin "run-dotzsh-init" ''
            #!/usr/bin/env bash
            if [ -f "${dotzsh-package}/bin/common.sh.in" ]; then
              exec bash "${dotzsh-package}/bin/common.sh.in" 1
            else
              echo "Error: common.sh.in not found in ${dotzsh-package}"
              exit 1
            fi
          '';
        };

        apps = {
          # Offer an app api to init
          run-dotzsh = {
            type = "app";
            program = "${pkgs.bash}/bin/bash ${dotzsh-package}/bin/common.sh.in 1";
          };
        };

        homeManagerModules = {
          default = hmModule;
          dotzsh = hmModule;
        };

        nixosModules = {
          default = nixosModule;
          dotzsh = nixosModule;
        };

        # Offer a dev shell for development and testing
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bash
            coreutils
          ];

          shellHook = ''
            echo "Development shell for dotzsh"
            echo "Available commands:"
            echo "  - bash ${./common.sh.in} 1  # Test the script directly"
            echo "  - nix run .#run-dotzsh      # Run via flake"
          '';
        };
      }
    );
    # // {
    #   ## All systems share the same modules, so we can just point them to the same definitions
    #   nixosModules = flake-utils.lib.eachDefaultSystem (system: {
    #     default = self.outputs.${system}.nixosModules.default;
    #     dotzsh = self.outputs.${system}.nixosModules.dotzsh;
    #   });

    #   homeManagerModules = flake-utils.lib.eachDefaultSystem (system: {
    #     default = self.outputs.${system}.homeManagerModules.default;
    #     dotzsh = self.outputs.${system}.homeManagerModules.dotzsh;
    #   });
    # };
}
