{ inputs }:
let
  lib = inputs.nixpkgs.lib;

  common =
    final: prev:
    let
      system = prev.stdenv.hostPlatform.system;
    in
    {
      # CVE-2026-111943: also protect packages using cacert directly, until
      # the cacert update reaches nixos-26.05.
      cacert = prev.cacert.override {
        blacklist = [
          "Comodo AAA Services root"
          "emSign ECC Root CA - G3"
          "emSign Root CA - C1"
          "emSign ECC Root CA - C3"
        ];
      };

      cachix = inputs.cachix-flake.packages.${system}.default;
      devenv = inputs.devenv.packages.${system}.devenv;

      # Run the latest-latest Nix
      nix-ci = final.callPackage ../pkgs/nix-ci.nix {
        nix = final.nixVersions.latest;
      };

      nix-clean-stale-state = final.callPackage ../pkgs/nix-clean-stale-state.nix { };

      # Skip the test-suite in case we have to build it ourselves.
      nodejs-slim_20 = prev.nodejs-slim_20.overrideAttrs { doCheck = false; };
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
