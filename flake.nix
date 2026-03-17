{
  description = "dotzsh - A Nix flake for managing zsh configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # flake-utils.url = "github:numtide/flake-utils";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell.url = "github:numtide/devshell";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [
      inputs.devshell.flakeModule
    ];

    flake.homeManagerModules.default = { config, lib, pkgs, ... }:
    let
      cfg = config.programs.dotzsh;
      ## usually is `~/.nix-profile/bin`, sometimes `/etc/profiles/per-user/$USER/bin`
      userNixProfileBin = "${config.home.profileDirectory}/bin";
      systemBin = "/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin";
    in {
      options.programs.dotzsh = {
        enable = lib.mkEnableOption "execute runsh shell";
        enableSourceZshrc = lib.mkEnableOption "init Content in .zshrc";
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
          home.packages = [ self.packages.${pkgs.system}.runsh ];
          ## Same to  `nix run .#runsh`
          home.activation.runMyShellInit = lib.hm.dag.entryAfter ["writeBoundary"] ''
            export PATH="${userNixProfileBin}:${systemBin}:$PATH"
            echo "--- Running dotzsh shell init in real environment ---"
            # echo "### Current PATH:"
            # echo "$PATH" | tr ':' '\n'
            # echo "### Current PATH [end]"
            ${self.packages.${pkgs.system}.runsh}/bin/runsh
            echo "--- Done ---"
          '';
        })

        (lib.mkIf cfg.enableSourceZshrc {
          ## Append the text at the end of $HOME/.zshrc
          programs.zsh.initContent = lib.mkOrder 1200 ''
            # --- github:handy/dotzsh flake auto-sourced ---
            source ${self}/zshrc
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

    perSystem = { pkgs, system, ... }: {
      packages = {
        runsh = pkgs.writeShellApplication {
          name = "runsh";
          runtimeInputs = [
            pkgs.bash
            pkgs.coreutils
          ];
          text = ''
            ${pkgs.bash}/bin/bash ${./common.sh.in} 1
          '';
        };
      };

      devshells.default = {
        commands = [
          {
            help = "runsh no help";
            name = "runsh";
            package = self.packages.${system}.runsh;
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
