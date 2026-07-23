{ inputs }:
let
  lib = inputs.nixpkgs.lib;

  common =
    final: prev:
    let
      system = prev.stdenv.hostPlatform.system;
    in
    {
      cachix = inputs.cachix-flake.packages.${system}.default;
      devenv = inputs.devenv.packages.${system}.devenv;
      nix-ci = final.callPackage ../pkgs/nix-ci.nix { nix = prev.nix; };
    };

  perSystem = {
    aarch64-darwin = final: prev: {
      devenv-x86 = inputs.devenv.packages.x86_64-darwin.devenv;
    };
  };
in
{
  inherit common perSystem;

  forSystem =
    system:
    let
      systemOverlay = perSystem.${system} or null;
    in
    [ common ] ++ lib.optional (systemOverlay != null) systemOverlay;
}
