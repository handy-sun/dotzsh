{
  description = "dotzsh - A Nix flake for managing zsh configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell.url = "github:numtide/devshell";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devshell.flakeModule
      ];

      flake.homeManagerModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.dotzsh;
          ## usually is `~/.nix-profile/bin`, sometimes `/etc/profiles/per-user/$USER/bin`
          userNixProfileBin = "${config.home.profileDirectory}/bin";
          systemBin = "/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin";
          setPathScript = ''
            export PATH="${userNixProfileBin}:${systemBin}:$PATH"
            if [ -f /opt/homebrew/bin/brew ]; then
              export PATH="/opt/homebrew/bin:$PATH"
            fi
          '';
        in
        {
          options.programs.dotzsh = {
            enable = lib.mkEnableOption "execute cm-init shell";
            enableZshIntegration = lib.mkEnableOption "init Content in .zshrc";
            enableFishIntegration = lib.mkEnableOption "init Content in .fishrc";
            enableFishPrompt = lib.mkEnableOption "set fish_prompt and fish_right_prompt";
          };

          config = lib.mkMerge [
            (lib.mkIf cfg.enable {
              home.packages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.cm-init ];
              ## Same to  `nix run .#cm-init` and `nix run .#fish-init`
              home.activation.runMyShellInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                ${setPathScript}
                echo "--- Running dotzsh shell init ---"
                # echo "### Current PATH:"
                # echo "$PATH" | tr ':' '\n'
                # echo "### Current PATH [end]"
                ${self.packages.${pkgs.stdenv.hostPlatform.system}.cm-init}/bin/dotzsh-cm
                ${self.packages.${pkgs.stdenv.hostPlatform.system}.fish-init}/bin/dotzsh-fish
                echo "--- Done ---"
              '';
            })

            (lib.mkIf cfg.enableZshIntegration {
              programs.zsh.initContent = lib.mkOrder 1200 ''
                # --- github:handy/dotzsh flake auto-sourced ---
                source ${self}/zshrc
              '';
            })

            (lib.mkIf cfg.enableFishIntegration {
              programs.fish.shellInitLast =
                let
                  commonFish = pkgs.runCommand "dotzsh-common.fish" { } ''
                    ${setPathScript}
                    ${pkgs.bash}/bin/bash ${./common.fish.in} stdout > $out
                  '';
                in
                ''
                  # --- github:handy/dotzsh flake auto-sourced ---
                  source ${commonFish}
                '';
            })

            (lib.mkIf cfg.enableFishPrompt {
              programs.fish.interactiveShellInit = builtins.readFile ./fish/prompt.fish;
            })
          ];
        };

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem =
        { pkgs, system, ... }:
        {
          packages = {
            cm-init = pkgs.writeShellApplication {
              name = "dotzsh-cm";
              runtimeInputs = [
                pkgs.bash
                pkgs.coreutils
              ];
              text = ''
                ${pkgs.bash}/bin/bash ${./common.sh.in} -1
              '';
            };
            fish-init = pkgs.writeShellApplication {
              name = "dotzsh-fish";
              runtimeInputs = [
                pkgs.bash
                pkgs.coreutils
              ];
              text = ''
                ${pkgs.bash}/bin/bash ${./common.fish.in} -1
              '';
            };
          };

          devshells.default = {
            commands = [
              {
                help = "no";
                name = "cm-init";
                package = self.packages.${system}.cm-init;
              }
              {
                help = "no";
                name = "fish-init";
                package = self.packages.${system}.fish-init;
              }
            ];
            devshell = {
              motd = ''
                🔨 Welcome to devshell{reset}
              '';
            };
          };
        };
    };
}
