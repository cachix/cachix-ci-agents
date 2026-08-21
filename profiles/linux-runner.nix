# Reusable role for a Linux GitHub Actions runner. Shared by every
# Linux CI agent, regardless of which physical/virtual host it runs on.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./common.nix
    ./github-runner.nix
  ];

  virtualisation.docker.enable = true;

  # Interrupted Nix builds can leave their temporary directories behind.
  # Build logs are disabled in common.nix; clean up logs written before that
  # setting changed.
  systemd.services.nix-clean-stale-state = {
    description = "Remove stale Nix build directories and build logs";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe pkgs.nix-clean-stale-state;
      Nice = 15;
      IOSchedulingClass = "idle";
    };
  };

  systemd.timers.nix-clean-stale-state = {
    description = "Daily stale Nix state cleanup";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:30:00";
      Persistent = true;
    };
  };

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

  # For certain services, like clickhouse.
  time.timeZone = lib.mkDefault "UTC";

  system.stateVersion = "23.11";
}
