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
                description = "The prefix to use for the runner name";
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
        runnerName = "${cfg.namePrefix}${toString index}";
      in
      lib.nameValuePair runnerName (
        lib.mkMerge [
          {
            enable = cfg.enable;
            url = "https://github.com/${cfg.githubOrganization}";
            tokenFile = cfg.tokenFile;
            # Replace an existing runner with the same name, instead of erroring out.
            replace = true;
            # Re-launch the runner after each job.
            ephemeral = true;
            extraPackages =
              with (if cfg.rosetta.enable then pkgs.pkgsx86_64Darwin else pkgs);
              [
                # custom
                cachix
                tmate
                jq
                git
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
              (lib.optionalAttrs pkgs.stdenv.isLinux {
                # needed for Cachix installation to work
                ReadWritePaths = [ "/nix/var/nix/profiles/per-user/" ];

                # Allow writing to $HOME
                ProtectHome = "tmpfs";

                # Always restart, which is possible with a PAT.
                Restart = lib.mkForce "always";
                RestartSec = "30s";
              })
              cfg.serviceOverrides
            ];
          }
          (lib.mkIf cfg.rosetta.enable {
            noDefaultLabels = true;
            extraLabels = [ "self-hosted" "X64" "macOS" ];
            extraEnvironment = {
              "NIX_USER_CONF_FILES" = "${pkgs.writeText "x86-nix-user-conf" ''
                system = x86_64-darwin
              ''}";
            };
          })
          (lib.mkIf pkgs.stdenv.isLinux { user = runnerName; })
          cfg.extraService
        ]
      )
    )
  );

  config.nix.settings = lib.mkIf anyRunnerEnabled {
    trusted-users =
      if pkgs.stdenv.isLinux
      then [ "@${cfg.group}" ]
      else if pkgs.stdenv.isDarwin
      then [ "_github-runner" ]
      else [ ];
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
            runnerName = "${cfg.namePrefix}${toString index}";
          in
          lib.nameValuePair runnerName {
            group = config.cachix.github-runners.group;
            extraGroups = config.cachix.github-runners.extraGroups;

            # Make sure we don't create home as the runner does
            isSystemUser = true;

            # Software like openssh executes getpwuid to get user's home.
            # because they won't want you to exploit setting $HOME.
            # On the other hand, systemd DynamicUser=1 sets it to /, which results into ...
            # a lot of confusion.
            # we set home entry in nss to match $HOME
            home = "/run/github-runner/${runnerName}";

            # Allow interactive shells (e.g. nix shell)
            useDefaultShell = true;
          }
        )
      );
    })
    # The nix-darwin module already creates the user and group.
    # TODO: create macOS users as well to have consistency
  ];
}
