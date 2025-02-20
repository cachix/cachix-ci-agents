{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/common.nix
    ../modules/github-runner.nix
  ];

  virtualisation.docker.enable = true;

  cachix.github-runners = {
    group = "_github-runner";
    extraGroups = [ "docker" ];

    runners.default = {
        enable = true;
        count = 4;
        githubOrganization = "cachix";
        namePrefix = "cachix-${pkgs.stdenv.system}-";
        tokenFile = config.age.secrets.github-runner-token.path;
        extraPackages = [ pkgs.devenv ];
        serviceOverrides = {
          ReadWritePaths = [
            (toString config.age.secrets.nix-access-tokens.path)
          ];
        };
    };
  };

  system.stateVersion = "23.11";
}
