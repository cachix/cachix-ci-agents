# A NixOS machine that runs GitHub Actions runners.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [ ./common.nix ];

  services.cachix-agent.verbose = lib.mkDefault true;

  virtualisation.docker.enable = lib.mkDefault true;

  cachix.github-runners.extraGroups = lib.optional config.virtualisation.docker.enable "docker";

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
}
