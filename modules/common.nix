{ config, pkgs, lib, ... }:

{
  nix.package = pkgs.nixVersions.nix_2_23;
  nix.settings.trusted-users = [ "root "];
  nix.extraOptions = ''
    always-allow-substitutes = true
    min-free = ${toString (10 * 1024 * 1024 * 1024)}
    max-free = ${toString (30 * 1024 * 1024 * 1024)}
    extra-experimental-features = flakes nix-command
  '';

  environment.systemPackages = with pkgs; [
    vim
    # zig broken on darwin
    #ncdu
    git
    tmux
    cachix
    direnv
  ];

  age.secrets.github-runner-token = {
    file = ../secrets/github-runner-token.age;
    group = config.cachix.github-runner.group;
  } // lib.optionalAttrs pkgs.stdenv.isDarwin {
    owner = config.cachix.github-runner.group;
  };
}
