{ config, lib, ... }:

{
  options = {
    enable = lib.mkEnableOption "this group of GitHub runners";

    count = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "The number of runners in the group.";
    };

    namePrefix = lib.mkOption {
      type = lib.types.str;
      default = "github-runner-";
      description = "The prefix of the runner name that GitHub shows.";
    };

    servicePrefix = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "The prefix of the service name on the machine.";
    };

    name = lib.mkOption {
      type = lib.types.functionTo lib.types.str;
      default = number: "${config.namePrefix}r${toString number}";
      defaultText = lib.literalExpression ''number: "''${namePrefix}r''${toString number}"'';
      description = ''
        The name that GitHub shows, as a function of the number of the
        runner in the group. Numbers start at 1.
      '';
    };

    service = lib.mkOption {
      type = lib.types.functionTo lib.types.str;
      default = number: "${config.servicePrefix}r${toString number}";
      defaultText = lib.literalExpression ''number: "''${servicePrefix}r''${toString number}"'';
      description = ''
        The `services.github-runners` attribute name, as a function of
        the number of the runner in the group. The systemd or launchd
        service is `github-runner-<service>`.
      '';
    };

    user = lib.mkOption {
      type = lib.types.functionTo lib.types.str;
      default = service: "github-runner-${service}";
      defaultText = lib.literalExpression ''service: "github-runner-''${service}"'';
      description = ''
        Linux only. The user that runs the runner, as a function of the
        service name.
      '';
    };

    home = lib.mkOption {
      type = lib.types.functionTo lib.types.str;
      default = service: "/var/lib/github-runner/${service}";
      defaultText = lib.literalExpression ''service: "/var/lib/github-runner/''${service}"'';
      description = ''
        Linux only. The home directory of the runner user, as a function
        of the service name.
      '';
    };

    workDir = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo lib.types.str);
      default = service: "/var/lib/github-runner-work/${service}";
      defaultText = lib.literalExpression ''service: "/var/lib/github-runner-work/''${service}"'';
      description = ''
        Linux only. The work directory of the runner, as a function of
        the service name. systemd creates directories under /var/lib.
        `null` keeps the upstream default under /run.
      '';
    };

    githubOrganization = lib.mkOption {
      type = lib.types.str;
      description = "The GitHub organization to register the runners with.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        A path to a file containing a PAT token.

        Create a fine-grained PAT token for an organization with the following permissions:
        - Self-hosted runners: Read and Write

        https://github.com/settings/personal-access-tokens/new
      '';
    };

    rosetta.enable = lib.mkEnableOption "Rosetta on Apple Silicon";

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages to add to the runner PATH.";
    };

    systemd.after = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Linux only. Order each runner after these systemd units when both
        are started. This does not start the listed units.
      '';
    };

    systemd.requires = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Linux only. Systemd units required by each runner.
        Also set `systemd.after` to wait for them to finish starting.
      '';
    };

    serviceOverrides = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Extra settings for the systemd or launchd service of each runner.
        Use this to, for example, adjust the sandboxing options.
      '';
    };

    extraService = lib.mkOption {
      type = lib.types.anything;
      default = { };
      description = "Extra `services.github-runners.<name>` settings for each runner.";
    };
  };
}
