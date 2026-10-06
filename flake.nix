{
  description = "Cachix CI Agents";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Nix 2.35.2 until the package bump reaches nixpkgs-unstable.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/59acf1c0bbf3a4715bc07cbdf973cdf908060570";
    devenv.url = "github:cachix/devenv/latest";

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cachix-deploy-flake = {
      url = "github:cachix/cachix-deploy-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.disko.follows = "disko";
      inputs.darwin.follows = "darwin";
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
      projectLib = import ./lib { inherit inputs; };
      machines = import ./machines {
        inherit inputs;
        sshKeys = import ./ssh-keys.nix;
      };
    in
    (projectLib.mkFlake { inherit machines; })
    // {
      lib = projectLib;
    };
}
