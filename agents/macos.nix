{ config, pkgs, lib, ... }:

let
  mkRunnerGroup = lib.callPackage ../lib/runners.nix {};
in
{
  imports = [
    ../modules/common.nix
    ../modules/github-runner.nix
  ];

  nix.settings.trusted-users = ["hetzner"];

  networking.hostName = "macos";
  services.cachix-agent.enable = true;

  # nix-darwin will create the _github-runner user and group for us.
  services.github-runners = mkRunnerGroup {
    enable = true;
    count = 2;
    githubOrganization = "cachix";
    namePrefix = "cachix-${pkgs.stdenv.system}";
    tokenFile = config.age.secrets.github-runner-token.path;
    extraPackages = [ pkgs.devenv ];
  } // mkRunnerGroup {
    enable = true;
    count = 2;
    githbOrganization = "cachix";
    namePrefix = "cachix-x86_64-darwin-rosetta";
    enableRosetta = true;
    tokenFile = config.age.secrets.github-runner-token.path;
    extraPackages = [ pkgs.devenv ];
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
