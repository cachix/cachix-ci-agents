{
  description = "Cachix CI Agents";

  inputs = {
    cachix-deploy-flake.url = "github:cachix/cachix-deploy-flake";
    devenv.url = "github:cachix/devenv/v0.6";
  };

  outputs = { self, devenv, nixpkgs, cachix-deploy-flake, ... }: 
    let
      linuxMachineName = "linux";
      sshPubKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7CTy+OMdA1IfR3EEuL/8c9tWZvfzzDH9cYE1Fq8eFsSfcoFKtb/0tAcUrhYmQMJDV54J7cLvltaoA4MV788uKl+rlqy17rKGji4gC94dvtB9eIH11p/WadgGORnjdiIV1Df29Zmjlm5zqNo2sZUxs0Nya2I4Dpa2tdXkw6piVgMtVrqPCM4W5uorX8CE+ecOUzPOi11lyfCwLcdg0OugXBVrNNSfnJ2/4PrLm7rcG4edbonjWa/FvMAHxN7BBU5+aGFC5okKOi5LqKskRkesxKNcIbsXHJ9TOsiqJKPwP0H2um/7evXiMVjn3/951Yz9Sc8jKoxAbeH/PcCmMOQz+8z7cJXm2LI/WIkiDUyAUdTFJj8CrdWOpZNqQ9WGiYQ6FHVOVfrHaIdyS4EOUG+XXY/dag0EBueO51i8KErrL17zagkeCqtI84yNvZ+L2hCSVM7uDi805Wi9DTr0pdWzh9jKNAcF7DqN16inklWUjtdRZn04gJ8N5hx55g2PAvMYWD21QoIruWUT1I7O9xbarQEfd2cC3yP+63AHlimo9Aqmj/9Qx3sRB7ycieQvNZEedLE9xiPOQycJzzZREVSEN1EK1xzle0Hg6I7U9L5LDD8yXkutvvppFb27dzlr5MTUnIy+reEHavyF9RSNXHTo57myffl8zo2lPjcmFkffLZQ== ielectric@kaki";

      lib = nixpkgs.lib;
      forAllSystems = lib.genAttrs ["x86_64-linux" "aarch64-darwin"];
      common = system: rec {
        pkgs = nixpkgs.legacyPackages.${system};
        cachix-deploy-lib = cachix-deploy-flake.lib pkgs;
        bootstrapNixOS = cachix-deploy-lib.bootstrapNixOS { 
          system = system; 
          hostname = linuxMachineName;
          grubDevices = [ "/dev/nvme0n1"  "/dev/nvme1n1" ];
          sshPubKey = sshPubKey;
        };
      };
    in {
      nixosConfigurations.${linuxMachineName} = (common "x86_64-linux").bootstrapNixOS.nixos;

      checks = forAllSystems (system: 
        let 
          inherit (common system) pkgs bootstrapNixOS;
          cachix-deploy-lib = cachix-deploy-flake.lib pkgs;
        in lib.optionalAttrs (system == "x86_64-linux") {
            linux = cachix-deploy-lib.nixos {
              imports = [ bootstrapNixOS.module ./agents/linux.nix ];
              
              environment.systemPackages = [ devenv.packages.x86_64-linux.devenv ];
            };
          } // lib.optionalAttrs (system == "aarch64-darwin") {
            macos = cachix-deploy-lib.darwin {
              imports = [ ./agents/macos.nix ];

              environment.systemPackages = [ devenv.packages.aarch64-darwin.devenv ];
            };
          });

      packages = forAllSystems (system: {
        default = (common system).cachix-deploy-lib.spec {
          agents = {
            linux = self.checks."x86_64-linux".linux;
            macos = self.checks."aarch64-darwin".macos;
          };
        };
      });

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
