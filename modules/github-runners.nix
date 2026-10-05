{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cachix.github-runners;
  inherit (pkgs.stdenv) isLinux isDarwin;

  # The limit that GitHub sets for a runner name.
  maxRunnerNameLength = 64;

  enabledGroups = lib.filter (group: group.enable) (lib.attrValues cfg.runners);

  # One attribute set for each runner of each enabled group.
  runners = lib.concatMap (
    group:
    lib.genList (
      index:
      let
        id = "r${toString (index + 1)}";
      in
      {
        inherit group;
        # The name that GitHub shows.
        name = "${group.namePrefix}${id}";
        # The systemd or launchd service name.
        service = "${group.servicePrefix}${id}";
      }
    ) group.count
  ) enabledGroups;

  # Linux runs each runner as its own system user.
  # nix-darwin runs all runners as the `_github-runner` user that it creates.
  linuxUser = runner: "github-runner-${runner.service}";
  linuxHome = runner: "/var/lib/github-runner/${runner.service}";
  linuxWorkDir = runner: "/var/lib/github-runner-work/${runner.service}";

  # The tools that a workflow can expect on PATH.
  # `pkgs` is the x86_64-darwin package set for Rosetta runners.
  runnerPackages =
    pkgs: with pkgs; [
      # custom
      cachix
      tmate
      jq
      git
      gh
      # nixos
      openssh
      coreutils-full
      bashInteractive # bash with ncurses support
      bzip2
      cpio
      curl
      diffutils
      findutils
      gawk
      stdenv.cc.libc
      getent
      getconf
      gnugrep
      gnupatch
      gnused
      gnutar
      gzip
      xz
      locale
      less
      ncurses
      netcat
      nodejs_20
      procps
      time
      zstd
      unzip
      util-linux
      which
      nix
      nixos-rebuild
    ];

  linuxRunnerPackages = with pkgs; [
    strace
    mkpasswd
    # nixos
    acl
    attr
    libcap
  ];

  linuxServiceOverrides = runner: {
    # Default workDir is under RuntimeDirectory, which is backed by tmpfs.
    # Use a separate StateDirectory for workDir to avoid self-referential
    # symlinks (NixOS/nixpkgs#289422).
    StateDirectory = [ "github-runner-work/${runner.service}" ];

    # needed for Cachix installation to work
    ReadWritePaths = [ "/nix/var/nix/profiles/per-user/" ];

    # Allow writing to $HOME
    ProtectHome = "tmpfs";

    # Always restart, which is possible with a PAT.
    Restart = lib.mkForce "always";
    RestartSec = "30s";
  };

  darwinServiceOverrides = {
    # Restart the service if it crashes
    # TODO: figure out if we can wait for the token to be available.
    # launchd doesn't allow ordering of jobs.
    # I think what's happening is that the agenix job isn't done before we launch the runner, which then isn't restarted.
    # Some runners make it in time, some don't.
    # We can use wait4path, but that's not easy to work into the existing module.
    KeepAlive = lib.mkForce true;

    # Don't run on load.
    # Wait for agenix to create the token and use that as a trigger.
    # The token is automatically added to WatchPaths.
    RunAtLoad = lib.mkForce false;
  };

  # Register as an x86_64 macOS runner and run Nix for x86_64-darwin.
  rosettaRunner = {
    noDefaultLabels = true;
    extraLabels = [
      "self-hosted"
      "X64"
      "macOS"
    ];
    extraEnvironment = {
      "NIX_USER_CONF_FILES" = "${pkgs.writeText "x86-nix-user-conf" ''
        system = x86_64-darwin
      ''}";
    };
  };

  # The `services.github-runners.<service>` definition for one runner.
  mkRunner =
    runner:
    let
      inherit (runner) group;
    in
    lib.mkMerge [
      {
        enable = true;
        inherit (runner) name;
        inherit (group) tokenFile;
        url = "https://github.com/${group.githubOrganization}";
        # Replace an existing runner with the same name, instead of erroring out.
        replace = true;
        # Re-launch the runner after each job.
        ephemeral = true;
        nodeRuntimes = [
          "node20"
          "node24"
        ];
        extraPackages =
          runnerPackages (if group.rosetta.enable then pkgs.pkgsx86_64Darwin else pkgs)
          ++ lib.optionals isLinux linuxRunnerPackages
          ++ group.extraPackages;
        serviceOverrides = lib.mkMerge [
          (lib.mkIf isLinux (linuxServiceOverrides runner))
          (lib.mkIf isDarwin darwinServiceOverrides)
          group.serviceOverrides
        ];
      }
      (lib.mkIf group.rosetta.enable rosettaRunner)
      (lib.mkIf isLinux {
        user = linuxUser runner;
        workDir = linuxWorkDir runner;
      })
      group.extraService
    ];

  mkLinuxUser = runner: {
    inherit (cfg) group extraGroups;

    # Make sure we don't create home as the runner does
    isSystemUser = true;

    # Software like openssh executes getpwuid to get user's home.
    # because they won't want you to exploit setting $HOME.
    # On the other hand, systemd DynamicUser=1 sets it to /, which results into ...
    # a lot of confusion.
    # we set home entry in nss to match $HOME
    home = linuxHome runner;

    # Allow interactive shells (e.g. nix shell)
    useDefaultShell = true;
  };

  forRunners =
    key: value: lib.listToAttrs (map (runner: lib.nameValuePair (key runner) (value runner)) runners);
in
{
  options.cachix.github-runners = {
    group = lib.mkOption {
      type = lib.types.str;
      default = "_github-runner";
      description = "The primary group of each runner user.";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra groups of each runner user.";
    };

    runners = lib.mkOption {
      description = "Groups of GitHub runners with the same settings.";
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule {
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

            serviceOverrides = lib.mkOption {
              type = lib.types.attrs;
              default = { };
              description = ''
                Settings for the systemd or launchd service.
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
      );
    };
  };

  config = {
    assertions = map (runner: {
      assertion = lib.stringLength runner.name <= maxRunnerNameLength;
      message = "GitHub runner name `${runner.name}` is longer than ${toString maxRunnerNameLength} characters.";
    }) runners;

    # The runner groups do not depend on `services.github-runners`, so the
    # attribute names can be computed from them without infinite recursion.
    # See https://github.com/NixOS/nixpkgs/issues/231427#issuecomment-1545312478.
    services.github-runners = forRunners (runner: runner.service) mkRunner;

    nix.settings.trusted-users = lib.mkIf (runners != [ ]) (
      if isLinux then [ "@${cfg.group}" ] else [ "_github-runner" ]
    );

    users = lib.mkMerge [
      (lib.mkIf isLinux {
        groups.${cfg.group} = { };
        users = forRunners linuxUser mkLinuxUser;
      })
      # The nix-darwin module already creates the user and group.
      # TODO: create macOS users as well to have consistency
      (lib.mkIf isDarwin {
        # TODO: /private/var and /var are the same, but a recent software upgrade triggers a nix-darwin assertion.
        # The home path for this user was changed from /var/ to /private/var.
        users."_github-runner".home = lib.mkForce "/private/var/lib/github-runners";
        groups.${cfg.group}.members = [ "_github-runner" ];
      })
    ];
  };
}
