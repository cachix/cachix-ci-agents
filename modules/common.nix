{ config, pkgs, lib, ... }:

{
  nix.package = pkgs.unstable.nixVersions.latest.overrideScope (final: prev: {
    nix-store = prev.nix-store.overrideAttrs (old: {
      patches = (old.patches or []) ++ [
        # fix: re-check temp roots before deletion in GC to prevent race
        # https://github.com/cachix/nix/commit/80dd955222b90347fa7bfc745eba073e6f4e187c
        (pkgs.fetchpatch {
          url = "https://github.com/cachix/nix/commit/80dd955222b90347fa7bfc745eba073e6f4e187c.diff";
          stripLen = 2;
          hash = "sha256-ZQIeGSlUdqBeVhw6Hxu6/CnaJa8VNhZTcgKPgdaQo98=";
        })
        # fix: add temp roots for references before auto-GC to prevent race
        # https://github.com/cachix/nix/commit/173744a5efff29f62acc5a538eaedded0a73c996
        (pkgs.fetchpatch {
          url = "https://github.com/cachix/nix/commit/173744a5efff29f62acc5a538eaedded0a73c996.diff";
          stripLen = 2;
          hash = "sha256-og/hrYHLja1WGo6Ufz4fuV6WtwA+YNdekjTr2jLTWFc=";
        })
      ];
    });
  });
  nix.channel.enable = false;

  # Run GC every hour
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 3d";
  } // lib.optionalAttrs pkgs.stdenv.isLinux {
    dates = "*:00";
    randomizedDelaySec = "1800";
  } // lib.optionalAttrs pkgs.stdenv.isDarwin {
    interval =  {
      Minute = 0;
    };
  };

  # Optimse the store to save disk space.
  # Do not auto-optimise on macOS. Too many issues: https://github.com/NixOS/nix/issues/7273
  nix.optimise.automatic = pkgs.stdenv.isLinux;
  nix.settings.auto-optimise-store = pkgs.stdenv.isLinux;

  nix.settings.trusted-public-keys = [
    "cachix-ci-agents.cachix.org-1:qVO9icjGen2UY8QnkygVYKajmjwjp3l6cHUT6t+lkHs="
  ];

  nix.extraOptions = ''
    always-allow-substitutes = true
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
