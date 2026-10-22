# Defaults for a machine that runs GitHub Actions runners.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ../modules/ci-machine.nix
    ../modules/github-runners.nix
    ../modules/secrets.nix
  ];

  # CVE-2026-111943: distrust compromised Comodo and emSign root certificates.
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
    "emSign Root CA - C1"
    "emSign ECC Root CA - C3"
  ];

  nix.package = lib.mkDefault pkgs.nix-ci;
  nix.channel.enable = lib.mkDefault false;

  # Run GC every hour
  nix.gc = {
    automatic = lib.mkDefault true;
    options = lib.mkDefault "--delete-older-than 3d";
  }
  // lib.optionalAttrs pkgs.stdenv.isLinux {
    dates = lib.mkDefault "*:00";
    randomizedDelaySec = lib.mkDefault "1800";
  }
  // lib.optionalAttrs pkgs.stdenv.isDarwin {
    interval = lib.mkDefault {
      Minute = 0;
    };
  };

  # Optimse the store to save disk space.
  # Do not auto-optimise on macOS. Too many issues: https://github.com/NixOS/nix/issues/7273
  nix.optimise.automatic = lib.mkDefault pkgs.stdenv.isLinux;
  nix.settings = {
    auto-optimise-store = lib.mkDefault pkgs.stdenv.isLinux;

    # Leave enough emergency space for SQLite and the garbage collector to
    # operate when the store volume is otherwise full.
    gc-reserved-space = lib.mkDefault (512 * 1024 * 1024);

    # CI logs are already captured by the runner. Do not retain another
    # unbounded copy under /nix/var/log/nix.
    keep-build-log = lib.mkDefault false;
  };

  nix.extraOptions = ''
    always-allow-substitutes = true
    extra-experimental-features = flakes nix-command
  ''
  + lib.optionalString (config.cachix.machine.nixAccessTokensFile != null) ''
    !include ${config.cachix.machine.nixAccessTokensFile}
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
}
