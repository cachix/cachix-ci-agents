{
  description = "Cachix CI Agents";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    devenv.url = "github:cachix/devenv/latest";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cachix-deploy-flake = {
      url = "github:cachix/cachix-deploy-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.disko.follows = "disko";
      inputs.darwin.follows = "nix-darwin";
      inputs.nixos-anywhere.inputs.flake-parts.follows = "devenv/flake-parts";
      inputs.nixos-anywhere.inputs.treefmt-nix.follows = "devenv/nixd/treefmt-nix";
    };

    cachix-flake = {
      url = "github:cachix/cachix";
      # inputs.nixpkgs.follows = "nixpkgs";
      inputs.devenv.follows = "devenv";
      inputs.flake-compat.follows = "devenv/flake-compat";
      inputs.git-hooks.follows = "devenv/git-hooks";
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

  outputs =
    inputs:
    let
      projectLib = import ./lib {
        inherit (inputs.nixpkgs) lib;
        overlaysFor = (import ./overlays { inherit inputs; }).forSystem;
      };
      nixpkgsConfig = {
        # The GitHub runner requires the EOL nodejs 20.
        allowInsecurePredicate =
          pkg:
          builtins.elem (inputs.nixpkgs.lib.getName pkg) [
            "nodejs"
            "nodejs-slim"
          ]
          && inputs.nixpkgs.lib.versions.major (inputs.nixpkgs.lib.getVersion pkg) == "20";
      };
      bootstrapDarwinFor = pkgs: pkgs.callPackage ./scripts/bootstrap-darwin { };
      pkgsForSystem = projectLib.pkgsFor {
        inherit inputs;
        config = nixpkgsConfig;
      };
      machines = projectLib.mkMachines {
        inherit inputs pkgsForSystem;
        machines = import ./machines { inherit inputs; };
      };
      deployment = projectLib.mkFlake { inherit machines; };
      forAllSystems =
        f:
        inputs.nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (
          system:
          f {
            inherit system;
            pkgs = pkgsForSystem system;
          }
        );
    in
    deployment
    // {
      packages = forAllSystems (
        { system, pkgs }:
        deployment.packages.${system} or { }
        // {
          inherit (pkgs) nix-ci nix-clean-stale-state;
          bootstrap-darwin = bootstrapDarwinFor pkgs;
        }
      );

      devShells = forAllSystems (
        { system, pkgs }:
        {
          default = pkgs.mkShell {
            buildInputs = [
              inputs.cachix-deploy-flake.packages.${system}.bootstrapHetzner
              (bootstrapDarwinFor pkgs)
              inputs.agenix.packages.${system}.default
            ];
          };
        }
      );

      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt);

      lib = projectLib;

      nixosModules.default = ./profiles/linux-runner.nix;
      darwinModules.default = ./profiles/macos-runner.nix;
    };
}
