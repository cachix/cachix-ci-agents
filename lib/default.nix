{ inputs }:

let
  overlays = import ../overlays { inherit inputs; };

  pkgsFor =
    system:
    import ../pkgs {
      inherit (inputs) nixpkgs;
      inherit system;
      overlays = overlays.forSystem system;
    };

  mkLib = args: import ./mk-lib.nix args;

  baseLib = mkLib {
    inherit (inputs) nixpkgs darwin cachix-deploy-flake;
    inherit pkgsFor;
  };

  defaultDevShellFor =
    system:
    (pkgsFor system).mkShell {
      buildInputs = [
        inputs.cachix-deploy-flake.packages.${system}.bootstrapHetzner
        inputs.agenix.packages.${system}.default
      ];
    };

  defaultExtraPackagesFor = system: {
    nix-ci = (pkgsFor system).nix-ci;
    nix-clean-stale-state = (pkgsFor system).nix-clean-stale-state;
  };
in
baseLib
// {
  inherit
    overlays
    pkgsFor
    mkLib
    ;

  mkFlake =
    {
      machines,
      systems ? null,
      devShellFor ? defaultDevShellFor,
      extraPackagesFor ? defaultExtraPackagesFor,
    }:
    baseLib.mkFlake {
      inherit
        machines
        systems
        devShellFor
        extraPackagesFor
        ;
    };
}
