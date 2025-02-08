{ config, pkgs, lib, ... }:

let
  mkRunnerGroup = lib.callPackage ../lib/runners.nix {};
in
{
  imports = [
    ../modules/common.nix
    ../modules/github-runner.nix
  ];

  virtualisation.docker.enable = true;

  users = {
    groups."_github-runner" = { };

    users."_github-runner" = {
      group = "_github-runner";
      extraGroups = [ "docker" ];

      # make sure we don't create home as the runner does
      isSystemUser = true;

      # Software like openssh executes getpwuid to get user's home.
      # because they won't want you to exploit setting $HOME.
      # On the other hand, systemd DynamicUser=1 sets it to /, which results into ...
      # a lot of confusion.
      # we set home entry in nss to match $HOME
      home = "/run/github-runner/github-runner";
    };
  };

  services.github-runners = mkRunnerGroup {
    enable = true;
    count = 4;
    githubOrganization = "cachix";
    namePrefix = "cachix-${pkgs.stdenv.system}";
    extraPackages = [ pkgs.devenv ];
    tokenFile = config.age.secrets.github-runner-token.path;
    serviceOverrides = {
      ReadWritePaths = [
        (toString config.age.secrets.nix-access-tokens.path)
      ];
    };
    user = "_github-runner";
    group = "_github-runner";
  };

  system.stateVersion = "23.11";
}
