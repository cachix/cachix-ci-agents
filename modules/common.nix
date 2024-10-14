{ config, pkgs, ... }:

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
    owner = if pkgs.stdenv.isDarwin then config.cachix.github-runner.group else null;
    group = config.cachix.github-runner.group;
  };
}
