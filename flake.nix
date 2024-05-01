{
  description = "Cachix CI Agents";

  inputs = {
    cachix-deploy-flake.url = "github:cachix/cachix-deploy-flake";
    devenv.url = "github:cachix/devenv/latest";
    cachix-flake.url = "github:cachix/cachix/debug-daemon-stop";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    srvos.url = "github:numtide/srvos";
    disko.url = "github:nix-community/disko";
  };

  nixConfig = {
    extra-substituters = [
      "https://cachix-ci-agents.cachix.org"
      "https://cachix.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cachix-ci-agents.cachix.org-1:qVO9icjGen2UY8QnkygVYKajmjwjp3l6cHUT6t+lkHs="
      "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
    ];
  };

  outputs = { self, devenv, nixpkgs, cachix-deploy-flake, cachix-flake, srvos, disko, ... }:
    let
      linuxMachineName = "linux";
      sshPubKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7CTy+OMdA1IfR3EEuL/8c9tWZvfzzDH9cYE1Fq8eFsSfcoFKtb/0tAcUrhYmQMJDV54J7cLvltaoA4MV788uKl+rlqy17rKGji4gC94dvtB9eIH11p/WadgGORnjdiIV1Df29Zmjlm5zqNo2sZUxs0Nya2I4Dpa2tdXkw6piVgMtVrqPCM4W5uorX8CE+ecOUzPOi11lyfCwLcdg0OugXBVrNNSfnJ2/4PrLm7rcG4edbonjWa/FvMAHxN7BBU5+aGFC5okKOi5LqKskRkesxKNcIbsXHJ9TOsiqJKPwP0H2um/7evXiMVjn3/951Yz9Sc8jKoxAbeH/PcCmMOQz+8z7cJXm2LI/WIkiDUyAUdTFJj8CrdWOpZNqQ9WGiYQ6FHVOVfrHaIdyS4EOUG+XXY/dag0EBueO51i8KErrL17zagkeCqtI84yNvZ+L2hCSVM7uDi805Wi9DTr0pdWzh9jKNAcF7DqN16inklWUjtdRZn04gJ8N5hx55g2PAvMYWD21QoIruWUT1I7O9xbarQEfd2cC3yP+63AHlimo9Aqmj/9Qx3sRB7ycieQvNZEedLE9xiPOQycJzzZREVSEN1EK1xzle0Hg6I7U9L5LDD8yXkutvvppFb27dzlr5MTUnIy+reEHavyF9RSNXHTo57myffl8zo2lPjcmFkffLZQ== ielectric@kaki";

      lib = nixpkgs.lib;
      forAllSystems = lib.genAttrs ["x86_64-linux" "aarch64-darwin" "aarch64-linux"];

      common = system: rec {
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              cachix = cachix-flake.packages.${system}.default;
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
          sshPubKey = sshPubKey;
        };
      };

      aarch64-linux-modules = [
        srvos.nixosModules.hardware-hetzner-cloud
        srvos.nixosModules.server
        srvos.nixosModules.mixins-systemd-boot
        disko.nixosModules.disko
        ./agents/linux.nix
        (import ./disko-hetzner-cloud.nix { disks = [ "/dev/sda" ]; })
        {
          services.cachix-agent.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;
          networking.hostName = "aarch64-linux";
          users.users.root.openssh.authorizedKeys.keys = [ sshPubKey ];
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
          inherit (common "x86_64-linux") cachix-deploy-lib pkgs bootstrapNixOS;
        in
        cachix-deploy-lib.nixos {
          imports = [
            bootstrapNixOS.module ./agents/linux.nix
          ];

          # TODO: This should also be set for bootstrapping
          boot.loader.grub.efiSupport = lib.mkForce false;
          boot.loader.grub.efiInstallAsRemovable = lib.mkForce false;

          services.github-runners."cachix-${pkgs.stdenv.system}".extraPackages = [ devenv.packages.x86_64-linux.devenv ];

          environment.systemPackages = [ devenv.packages.x86_64-linux.devenv ];
        };

      packages.aarch64-linux.default =
        let
          inherit (common "aarch64-linux") cachix-deploy-lib pkgs;
        in
        cachix-deploy-lib.nixos {
          imports = aarch64-linux-modules;

          # try to limit memory usage
          nix.settings.max-jobs = 8;

          services.github-runners."cachix-${pkgs.stdenv.system}".extraPackages = [ devenv.packages.aarch64-linux.devenv ];

          environment.systemPackages = [ devenv.packages.aarch64-linux.devenv ];
        };

      packages.aarch64-darwin.default =
        let
          inherit (common "aarch64-darwin") cachix-deploy-lib;
        in
        cachix-deploy-lib.darwin {
          imports = [ ./agents/macos.nix ];

          environment.systemPackages = [ devenv.packages.aarch64-darwin.devenv ];
        };

      devShells = forAllSystems (system:
        let
          inherit (common system) pkgs;
        in {
        default = pkgs.mkShell {
          buildInputs = [
            cachix-deploy-flake.packages.${system}.bootstrapHetzner
          ];
        };
      });
  }; 
}
