{
  config,
  lib,
  ...
}:

let
  cfg = config.cachix.machine;
  GiB = 1024 * 1024 * 1024;
in
{
  options.cachix.machine = {
    hardware = {
      cpus = lib.mkOption {
        type = lib.types.ints.positive;
        description = "Number of logical CPUs.";
      };

      memory = lib.mkOption {
        type = lib.types.ints.positive;
        description = "RAM in GiB.";
      };

      disk = lib.mkOption {
        type = lib.types.ints.positive;
        description = "Size of the disk that holds the Nix store, in GiB.";
      };
    };

    adminUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "root" ];
      description = ''
        Users that admins log in as over SSH.
        They get the admin SSH keys and are trusted by Nix.
      '';
    };

    adminKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys of the admins.";
    };

    runners = lib.mkOption {
      type = lib.types.ints.positive;
      default = lib.max 1 (lib.min (cfg.hardware.memory / 8) (cfg.hardware.cpus / 4));
      defaultText = lib.literalExpression "max 1 (min (memory / 8) (cpus / 4))";
      description = "Number of GitHub runners.";
    };

    maxJobs = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2 * cfg.runners;
      defaultText = lib.literalExpression "2 * runners";
      description = "Number of Nix builds that run at the same time.";
    };

    cores = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 0;
      description = ''
        Maximum CPUs for each Nix build.
      '';
    };

    minFree = lib.mkOption {
      type = lib.types.ints.positive;
      default = lib.max 10 (cfg.hardware.disk * 5 / 100);
      defaultText = lib.literalExpression "max 10 (disk * 5 / 100)";
      description = ''
        Free space in GiB below which Nix starts to collect garbage.
      '';
    };

    maxFree = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2 * cfg.minFree;
      defaultText = lib.literalExpression "2 * minFree";
      description = ''
        Free space in GiB at which Nix stops to collect garbage.
      '';
    };
  };

  config = {
    nix.settings = {
      max-jobs = cfg.maxJobs;
      cores = cfg.cores;
      min-free = cfg.minFree * GiB;
      max-free = cfg.maxFree * GiB;
      # Nix always trusts root.
      trusted-users = lib.remove "root" cfg.adminUsers;
    };

    users.users = lib.genAttrs cfg.adminUsers (_: {
      openssh.authorizedKeys.keys = cfg.adminKeys;
    });

    services.cachix-agent.enable = true;
    services.openssh.enable = true;
  };
}
