# A NixOS machine that runs GitHub Actions runners.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [ ./common.nix ];

  virtualisation.docker.enable = true;

  cachix.github-runners = {
    extraGroups = [ "docker" ];

    runners.default.serviceOverrides = {
      ReadWritePaths = [
        (toString config.age.secrets.nix-access-tokens.path)
      ];
    };
  };

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

  # For certain services, like clickhouse.
  time.timeZone = lib.mkDefault "UTC";

  system.stateVersion = "23.11";
}
