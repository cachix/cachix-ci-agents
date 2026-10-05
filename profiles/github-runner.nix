{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.cachix.github-runners;
  anyRunnerEnabled = lib.any (cfg: cfg.enable) (lib.attrValues config.cachix.github-runners.runners);
  genRunners =
    runners: f:
    lib.mapAttrsToList (
      name: cfg:
      lib.mkIf cfg.enable (lib.listToAttrs (lib.genList (index: f { inherit name index cfg; }) cfg.count))
    ) runners;

  # A machine has runners `r1`, `r2`, `r3`, and so on.
  runnerId = index: "r${toString (index + 1)}";

  # The name that GitHub shows.
  mkRunnerName = cfg: index: "${cfg.namePrefix}${runnerId index}";

  # A shorter systemd/launchd service name.
  mkServiceName = cfg: index: "${cfg.servicePrefix}${runnerId index}";

  enabledRunners = lib.filter (runner: runner.enable) (lib.attrValues cfg.runners);

  runnerNames = lib.concatMap (runner: lib.genList (mkRunnerName runner) runner.count) enabledRunners;

  # The limit that GitHub sets for a runner name.
  maxRunnerNameLength = 64;
in
{
  options.cachix.github-runners = {
    group = lib.mkOption {
      type = lib.types.str;
      default = "_github-runner";
      description = "The group to add each runner user to";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra groups to add to each runner user";
    };

    runners = lib.mkOption {
      description = "Customized GitHub runners";
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              enable = lib.mkEnableOption "GitHub runner group";

              count = lib.mkOption {
                type = lib.types.int;
                default = 1;
                description = "The number of runners to create";
              };

              namePrefix = lib.mkOption {
                type = lib.types.str;
                default = "github-runner-";
                description = ''
                  The prefix of the runner name that GitHub shows.
                '';
              };

              servicePrefix = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = ''
                  The prefix of the service name on the machine.
                '';
              };

              githubOrganization = lib.mkOption {
                type = lib.types.str;
                description = "The GitHub organization to register the runner with";
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

              rosetta.enable = lib.mkEnableOption "rosetta on Apple Silicon";

              extraService = lib.mkOption {
                type = lib.types.anything;
                default = { };
                description = "Extra service to run on the runner";
              };

              serviceOverrides = lib.mkOption {
                type = lib.types.attrs;
                default = { };
                description = ''
                  Modify the service. Can be used to, e.g., adjust the sandboxing options.
                '';
              };

              extraPackages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
                description = "Extra packages to add to the runner env";
              };
            };
          }
        )
      );
    };
  };

  # Create each GitHub runner
  # NOTE: see https://github.com/NixOS/nixpkgs/issues/231427#issuecomment-1545312478 how to prevent inf rec
  config.services.github-runners = lib.mkMerge (
    genRunners config.cachix.github-runners.runners (
      {
        name,
        index,
        cfg,
      }:
      let
        serviceName = mkServiceName cfg index;
        userName = "github-runner-${serviceName}";
      in
      lib.nameValuePair serviceName (
        lib.mkMerge [
          {
            enable = cfg.enable;
            name = mkRunnerName cfg index;
            url = "https://github.com/${cfg.githubOrganization}";
            tokenFile = cfg.tokenFile;
            # Replace an existing runner with the same name, instead of erroring out.
            replace = true;
            # Re-launch the runner after each job.
            ephemeral = true;
            nodeRuntimes = [
              "node20"
              "node24"
            ];
            extraPackages =
              with (if cfg.rosetta.enable then pkgs.pkgsx86_64Darwin else pkgs);
              [
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
              ]
              ++ lib.optionals pkgs.stdenv.isLinux [
                pkgs.strace
                pkgs.mkpasswd
                # nixos
                pkgs.acl
                pkgs.attr
                pkgs.libcap
              ]
              ++ lib.optionals pkgs.stdenv.isDarwin [ ]
              ++ cfg.extraPackages;
            serviceOverrides = lib.mkMerge [
              (lib.mkIf pkgs.stdenv.isLinux {
                # needed for Cachix installation to work
                ReadWritePaths = [ "/nix/var/nix/profiles/per-user/" ];

                # Allow writing to $HOME
                ProtectHome = "tmpfs";

                # Always restart, which is possible with a PAT.
                Restart = lib.mkForce "always";
                RestartSec = "30s";
              })
              (lib.mkIf pkgs.stdenv.isDarwin {
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
              })
              cfg.serviceOverrides
            ];
          }
          (lib.mkIf cfg.rosetta.enable {
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
          })
          (lib.mkIf pkgs.stdenv.isLinux {
            user = userName;
            # Default workDir is under RuntimeDirectory, which is backed by tmpfs.
            # Use a separate StateDirectory for workDir to avoid self-referential
            # symlinks (NixOS/nixpkgs#289422).
            serviceOverrides.StateDirectory = [
              "github-runner/${serviceName}"
              "github-runner-work/${serviceName}"
            ];
            workDir = "/var/lib/github-runner-work/${serviceName}";
          })
          cfg.extraService
        ]
      )
    )
  );

  config.assertions = map (name: {
    assertion = lib.stringLength name <= maxRunnerNameLength;
    message = "GitHub runner name `${name}` is longer than ${toString maxRunnerNameLength} characters.";
  }) runnerNames;

  config.nix.settings = lib.mkIf anyRunnerEnabled {
    trusted-users =
      if pkgs.stdenv.isLinux then
        [ "@${cfg.group}" ]
      else if pkgs.stdenv.isDarwin then
        [ "_github-runner" ]
      else
        [ ];
  };

  config.users = lib.mkMerge [
    (lib.mkIf (pkgs.stdenv.isLinux) {
      groups.${cfg.group} = { };

      users = lib.mkMerge (
        genRunners config.cachix.github-runners.runners (
          {
            name,
            index,
            cfg,
          }:
          let
            serviceName = mkServiceName cfg index;
          in
          lib.nameValuePair "github-runner-${serviceName}" {
            group = config.cachix.github-runners.group;
            extraGroups = config.cachix.github-runners.extraGroups;

            # Make sure we don't create home as the runner does
            isSystemUser = true;

            # Software like openssh executes getpwuid to get user's home.
            # because they won't want you to exploit setting $HOME.
            # On the other hand, systemd DynamicUser=1 sets it to /, which results into ...
            # a lot of confusion.
            # we set home entry in nss to match $HOME
            home = "/var/lib/github-runner/${serviceName}";

            # Allow interactive shells (e.g. nix shell)
            useDefaultShell = true;
          }
        )
      );
    })
    # The nix-darwin module already creates the user and group.
    # TODO: create macOS users as well to have consistency
    (lib.mkIf (pkgs.stdenv.isDarwin) {
      # TODO: /private/var and /var are the same, but a recent software upgrade triggers a nix-darwin assertion.
      # The home path for this user was changed from /var/ to /private/var.
      users."_github-runner".home = lib.mkForce "/private/var/lib/github-runners";
      groups.${cfg.group}.members = [ "_github-runner" ];
    })
  ];
}
