{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/common.nix
    ../modules/github-runner.nix
  ];

  nix.settings.trusted-users = ["hetzner"];

  networking.hostName = "macos";
  services.cachix-agent.enable = true;

  cachix.github-runners = {
    runners."aarch64-darwin" = {
      enable = true;
      count = 2;
      githubOrganization = "cachix";
      namePrefix = "cachix-${pkgs.stdenv.system}-";
      tokenFile = config.age.secrets.github-runner-token.path;
      extraPackages = [ pkgs.devenv ];
    };

    runners."x86_64-darwin" = {
      enable = true;
      count = 2;
      rosetta.enable = true;
      githubOrganization = "cachix";
      namePrefix = "cachix-x86_64-darwin-rosetta-";
      tokenFile = config.age.secrets.github-runner-token.path;
      extraPackages = [ pkgs.devenv-x86 ];
    };
  };

  # required on M1
  programs.zsh.enable = true;
  programs.zsh.interactiveShellInit = ''
    eval "$(direnv hook zsh)"
  '';

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;

  # Disable check for nixbld uid range.
  ids.uids.nixbld = 300;

  # for some reason manual isn't reproducible so we disable it
  documentation.man.enable = lib.mkForce false;
  documentation.info.enable = lib.mkForce false;
  documentation.doc.enable = lib.mkForce false;

  system.stateVersion = 5;
}
