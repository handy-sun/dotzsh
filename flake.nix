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
          inherit (lib) mkIf mkEnableOption;
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
            enable = mkEnableOption "execute cm-init shell";
            enableZshIntegration = mkEnableOption "init Content in .zshrc";
            enableFishIntegration = mkEnableOption "init Content in .fishrc";
            enableFishPrompt = mkEnableOption "set fish_prompt and fish_right_prompt";
            enableFishGreetingforNix = mkEnableOption "set fish_greeting for nix";
          };

          config = lib.mkMerge [
            (mkIf (cfg.enableZshIntegration && cfg.enable) {
              home.activation.runMyZshShellInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                ${setPathScript}
                ${self.packages.${pkgs.stdenv.hostPlatform.system}.cm-init}/bin/dotzsh-cm
              '';
              programs.zsh.initContent = lib.mkOrder 1200 ''
                # --- github:handy/dotzsh flake auto-sourced ---
                source ${self}/zshrc
              '';
            })

            (mkIf (cfg.enableFishIntegration && cfg.enable) {
              programs.fish.shellInitLast =
                let
                  extraArgs = (if cfg.enableFishGreetingforNix then "g" else "") + (if cfg.enableFishPrompt then "p" else "");
                  commonFish = pkgs.runCommand "dotzsh-common.fish" { } ''
                    ${setPathScript}
                    echo "### Current PATH:"
                    echo "$PATH" | tr ':' '\n'
                    echo "### Current PATH [end]"
                    echo extraArgs=${extraArgs}
                    ${pkgs.bash}/bin/bash ${./common.fish.in} "-0${extraArgs}" > $out
                  '';
                in
                ''
                  # --- github:handy/dotzsh flake auto-sourced ---
                  source ${commonFish}
                '';
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
