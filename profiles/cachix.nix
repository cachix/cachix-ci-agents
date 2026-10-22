# The GitHub runners of the cachix organization.
#
# This profile holds everything that is specific to the cachix deployment:
# secrets, the binary cache, and the runner groups.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkMerge [
    {
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

      cachix.secrets = {
        github-runner-token.path = config.age.secrets.github-runner-token.path;
        nix-access-tokens.path = config.age.secrets.nix-access-tokens.path;
      };

      cachix.machine.nixAccessTokensFile = config.cachix.secrets.nix-access-tokens.path;

      nix.settings.trusted-public-keys = [
        "cachix-ci-agents.cachix.org-1:qVO9icjGen2UY8QnkygVYKajmjwjp3l6cHUT6t+lkHs="
      ];

      cachix.github-runners.runners.default = {
        enable = true;
        count = config.cachix.machine.runners;
        githubOrganization = "cachix";
        namePrefix = "${config.networking.hostName}-";
        tokenFile = config.cachix.secrets.github-runner-token.path;
        extraPackages = [ pkgs.devenv ];
      };
    }

    (lib.mkIf pkgs.stdenv.isLinux {
      # Wait for agenix to rotate secrets and set permissions before mounting them.
      cachix.github-runners.runners.default.systemd = {
        requires = [ "agenix-chown.service" ];
        after = [ "agenix-chown.service" ];
      };

      # The runners only read the access tokens. `ProtectSystem = "strict"`
      # blocks writes, not reads, so this entry may not be needed.
      # Unverified. Kept to leave the deployed units unchanged.
      cachix.github-runners.runners.default.serviceOverrides.ReadWritePaths = [
        (toString config.cachix.secrets.nix-access-tokens.path)
      ];
    })

    (lib.mkIf pkgs.stdenv.isDarwin {
      # x86_64-darwin runners through Rosetta. Switched off for now.
      cachix.github-runners.runners."x86_64-darwin" = {
        enable = false;
        count = config.cachix.machine.runners;
        rosetta.enable = true;
        githubOrganization = "cachix";
        namePrefix = "${config.networking.hostName}-x86_64-";
        servicePrefix = "x86_64-";
        tokenFile = config.cachix.secrets.github-runner-token.path;
        extraPackages = [ pkgs.devenv-x86 ];
      };
    })
  ];
}
