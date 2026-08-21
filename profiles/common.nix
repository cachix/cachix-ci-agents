{
  config,
  pkgs,
  lib,
  ...
}:

{
  nix.package = pkgs.nix-ci;
  nix.channel.enable = false;

  # Run GC every hour
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 3d";
  }
  // lib.optionalAttrs pkgs.stdenv.isLinux {
    dates = "*:00";
    randomizedDelaySec = "1800";
  }
  // lib.optionalAttrs pkgs.stdenv.isDarwin {
    interval = {
      Minute = 0;
    };
  };

  # Optimse the store to save disk space.
  # Do not auto-optimise on macOS. Too many issues: https://github.com/NixOS/nix/issues/7273
  nix.optimise.automatic = pkgs.stdenv.isLinux;
  nix.settings = {
    auto-optimise-store = pkgs.stdenv.isLinux;

    trusted-public-keys = [
      "cachix-ci-agents.cachix.org-1:qVO9icjGen2UY8QnkygVYKajmjwjp3l6cHUT6t+lkHs="
    ];

    # Start collecting before CI fills the store volume, and collect enough
    # that the next few builds do not immediately trigger another GC.
    min-free = 10 * 1024 * 1024 * 1024;
    max-free = 20 * 1024 * 1024 * 1024;

    # Leave enough emergency space for SQLite and the garbage collector to
    # operate when the store volume is otherwise full.
    gc-reserved-space = 512 * 1024 * 1024;

    # CI logs are already captured by the runner. Do not retain another
    # unbounded copy under /nix/var/log/nix.
    keep-build-log = false;
  };

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
