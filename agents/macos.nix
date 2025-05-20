{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/common.nix
    ../modules/github-runner.nix
  ];

  nix.settings.trusted-users = ["hetzner"];

  networking.hostName = "macos";
  services.cachix-agent.enable = true;

  # Disable Touch ID and Watch ID pam integrations.
  # There's a permission error writing to /etc/pam.d.
  # Could be SIP related? We run our agent as root.
  security.pam.services.sudo_local.enable = false;

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
      enable = false;
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

  # Disable check for nixbld uid range.
  # WARN: remove after re-bootstrapping machine.
  ids.uids.nixbld = 300;
  ids.gids.nixbld = 30000;

  # for some reason manual isn't reproducible so we disable it
  documentation.man.enable = lib.mkForce false;
  documentation.info.enable = lib.mkForce false;
  documentation.doc.enable = lib.mkForce false;

  system.stateVersion = 5;
}
