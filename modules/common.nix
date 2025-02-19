{ config, pkgs, lib, ... }:

{
  nix.package = pkgs.nixVersions.nix_2_23;
  nix.settings.trusted-users = [ "root" ];
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
    owner = config.cachix.github-runner.group;
    group = config.cachix.github-runner.group;
    mode = "440";
  };

  age.secrets.nix-access-tokens = {
    file = ../secrets/nix-access-tokens.age;
    owner = config.cachix.github-runner.group;
    group = config.cachix.github-runner.group;
    mode = "440";
  };
}
