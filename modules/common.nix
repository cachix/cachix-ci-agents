{ config, pkgs, lib, ... }:

{
  # Use nix from unstable until curl 8.12 lands in 24.11
  # PR: https://github.com/NixOS/nixpkgs/pull/379541
  #
  # Unstable currently patches curl 8.11.1 to fix one of the netrc bugs that breaks cachix.
  nix.package = pkgs.unstable.nixVersions.nix_2_26;
  # Run GC every hour
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  } // lib.optionalAttrs pkgs.stdenv.isLinux {
    dates = "*:00";
    randomizedDelaySec = "1800";
  } // lib.optionalAttrs pkgs.stdenv.isDarwin {
    interval =  {
      Minute = 0;
    };
    # Our macOS install is single-user, so we can't run GC as root.
    user = "hetzner";
  };
  # Optimse the store to save disk space.
  # Do not auto-optimise on macOS. Too many issues: https://github.com/NixOS/nix/issues/7273
  nix.optimise.automatic = pkgs.stdenv.isLinux;
  nix.settings.auto-optimise-store = pkgs.stdenv.isLinux;
  nix.extraOptions = ''
    always-allow-substitutes = true
    min-free = ${toString (10 * 1024 * 1024 * 1024)}
    max-free = ${toString (30 * 1024 * 1024 * 1024)}
    extra-experimental-features = flakes nix-command
    !include ${config.age.secrets.nix-access-tokens.path}
  '';

  environment.systemPackages = with pkgs; [
    vim
    # zig broken on darwin
    #ncdu
    git
    tmux
    cachix
    devenv
    direnv
  ];

  age.secrets.github-runner-token = {
    file = ../secrets/github-runner-token.age;
    owner = "root";
    group = config.cachix.github-runners.group;
    mode = "440";
  };

  age.secrets.nix-access-tokens = {
    file = ../secrets/nix-access-tokens.age;
    owner = "root";
    group = config.cachix.github-runners.group;
    mode = "440";
  };
}
