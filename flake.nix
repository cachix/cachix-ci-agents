{
  description = "Cachix CI Agents";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    devenv.url = "github:cachix/devenv/latest";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.darwin.follows = "darwin";
    };

    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cachix-deploy-flake = {
      url = "github:cachix/cachix-deploy-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.disko.follows = "disko";
      inputs.darwin.follows = "darwin";
    };

    cachix-flake = {
      url = "github:cachix/cachix";
      # inputs.nixpkgs.follows = "nixpkgs";
      inputs.devenv.follows = "devenv";
    };

    srvos = {
      url = "github:numtide/srvos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://cachix-ci-agents.cachix.org"
      "https://devenv.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cachix-ci-agents.cachix.org-1:qVO9icjGen2UY8QnkygVYKajmjwjp3l6cHUT6t+lkHs="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
  };

  outputs = { self, devenv, nixpkgs, nixpkgs-unstable, cachix-deploy-flake, cachix-flake, srvos, disko, agenix, ... } @ inputs:
    let
      linuxMachineName = "linux";
      sshPubKeys = {
        domen = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7CTy+OMdA1IfR3EEuL/8c9tWZvfzzDH9cYE1Fq8eFsSfcoFKtb/0tAcUrhYmQMJDV54J7cLvltaoA4MV788uKl+rlqy17rKGji4gC94dvtB9eIH11p/WadgGORnjdiIV1Df29Zmjlm5zqNo2sZUxs0Nya2I4Dpa2tdXkw6piVgMtVrqPCM4W5uorX8CE+ecOUzPOi11lyfCwLcdg0OugXBVrNNSfnJ2/4PrLm7rcG4edbonjWa/FvMAHxN7BBU5+aGFC5okKOi5LqKskRkesxKNcIbsXHJ9TOsiqJKPwP0H2um/7evXiMVjn3/951Yz9Sc8jKoxAbeH/PcCmMOQz+8z7cJXm2LI/WIkiDUyAUdTFJj8CrdWOpZNqQ9WGiYQ6FHVOVfrHaIdyS4EOUG+XXY/dag0EBueO51i8KErrL17zagkeCqtI84yNvZ+L2hCSVM7uDi805Wi9DTr0pdWzh9jKNAcF7DqN16inklWUjtdRZn04gJ8N5hx55g2PAvMYWD21QoIruWUT1I7O9xbarQEfd2cC3yP+63AHlimo9Aqmj/9Qx3sRB7ycieQvNZEedLE9xiPOQycJzzZREVSEN1EK1xzle0Hg6I7U9L5LDD8yXkutvvppFb27dzlr5MTUnIy+reEHavyF9RSNXHTo57myffl8zo2lPjcmFkffLZQ== ielectric@kaki";
        sander = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO18rhoNZWQZeudtRFBZvJXLkHEshSaEFFt2llG5OeHk hey@sandydoo.me";
      };

      lib = nixpkgs.lib;
      forAllSystems = lib.genAttrs ["x86_64-linux" "aarch64-darwin" "aarch64-linux"];

      common = system: rec {
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              cachix = cachix-flake.packages.${system}.default;
              devenv = devenv.packages.${system}.devenv;
              unstable = nixpkgs-unstable.legacyPackages.${system};
            } // lib.optionalAttrs (system == "aarch64-darwin") {
              devenv-x86 = devenv.packages.x86_64-darwin.devenv;
            })
          ];
        };
        cachix-deploy-lib = cachix-deploy-flake.lib pkgs;
        bootstrapNixOS =
          let
            grubDevices = [ "/dev/nvme0n1"  "/dev/nvme1n1" ];
          in cachix-deploy-lib.bootstrapNixOS {
          system = system;
          hostname = linuxMachineName;
          diskoDevices = import ./disko-mdadm.nix { disks = grubDevices; };
          inherit grubDevices;
          sshPubKey = sshPubKeys.domen;
        };
      };

      aarch64-linux-modules = [
        srvos.nixosModules.hardware-hetzner-cloud
        srvos.nixosModules.server
        srvos.nixosModules.mixins-systemd-boot
        disko.nixosModules.disko
        agenix.nixosModules.default
        ./agents/linux.nix
        (import ./disko-hetzner-cloud.nix { disks = [ "/dev/sda" ]; })
        {
          services.cachix-agent.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;
          networking.hostName = "aarch64-linux";
          users.users.root.openssh.authorizedKeys.keys = builtins.attrValues sshPubKeys;
          services.openssh.enable = true;
          services.openssh.settings.PermitRootLogin = "without-password";
      }];
    in {
      nixosConfigurations.${linuxMachineName} = (common "x86_64-linux").bootstrapNixOS.nixos;
      nixosConfigurations."aarch64-linux" = lib.nixosSystem {
        system = "aarch64-linux";
        pkgs = (common "aarch64-linux").pkgs;
        modules = aarch64-linux-modules;
      };

      packages.x86_64-linux.default =
        let
          inherit (common "x86_64-linux") cachix-deploy-lib bootstrapNixOS;
        in
        cachix-deploy-lib.nixos {
          imports = [
            bootstrapNixOS.module ./agents/linux.nix
            agenix.nixosModules.default
          ];

          # TODO: This should also be set for bootstrapping
          boot.loader.grub.efiSupport = lib.mkForce false;
          boot.loader.grub.efiInstallAsRemovable = lib.mkForce false;
          boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

          users.users.root.openssh.authorizedKeys.keys = builtins.attrValues sshPubKeys;
        };

      packages.aarch64-linux.default =
        let
          inherit (common "aarch64-linux") cachix-deploy-lib;
        in
        cachix-deploy-lib.nixos {
          imports = aarch64-linux-modules;

          # try to limit memory usage
          nix.settings.max-jobs = 8;
        };

      packages.aarch64-darwin.default =
        let
          inherit (common "aarch64-darwin") cachix-deploy-lib;
        in
        cachix-deploy-lib.darwin {
          imports = [
            ./agents/macos.nix
            agenix.darwinModules.default
          ];

          users.users.hetzner.openssh.authorizedKeys.keys = builtins.attrValues sshPubKeys;
        };

      devShells = forAllSystems (system:
        let
          inherit (common system) pkgs;
        in {
        default = pkgs.mkShell {
          buildInputs = [
            cachix-deploy-flake.packages.${system}.bootstrapHetzner
            agenix.packages.${system}.default
          ];
        };
      });
  }; 
}
