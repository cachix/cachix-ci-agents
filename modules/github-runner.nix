{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.cachix.github-runner;
in
{
  options.cachix.github-runner = {
    enable = lib.mkEnableOption "Enable github runners.";

    namePrefix = lib.mkOption {
      type = lib.types.str;
      description = "The prefix to use for the runner name";
    };

    githubOrganization = lib.mkOption {
      type = lib.types.str;
      description = "The github organization to register the runner with";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      description = "The file containing the PAT token";
    };

    group = lib.mkOption {
      type = lib.types.str;
      description = "The group create and run the runner as";
      default = "_github-runner";
    };

    enableRosetta = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable rosetta on Apple Silicon";
    };

    count = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Number of runners to start";
    };

    extraService = lib.mkOption {
      type = lib.types.anything;
      default = { };
      description = "Extra service to run on the runner";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages to add to the runner env";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra groups to add to each github user";
    };
  };

  # create each github runner
  # NOTE: see https://github.com/NixOS/nixpkgs/issues/231427#issuecomment-1545312478 how to prevent inf rec
  config = lib.mkIf cfg.enable (lib.mkMerge [
    (let
      name = i: "${cfg.namePrefix}-${toString i}";
      runners = lib.range 1 cfg.count;
      mkRunner = f: builtins.foldl' (acc: i: acc // { ${name i} = f i; }) { } runners;
    in
    {
      nix.settings.trusted-users =
        if pkgs.stdenv.isLinux then builtins.map name runners else [ "_github-runner" ];

      services.github-runners = mkRunner (
        i:
        {
          enable = true;
          url = "https://github.com/${cfg.githubOrganization}";
          tokenFile = cfg.tokenFile;
          # Replace an existing runner with the same name, instead of erroring out.
          replace = true;
          user = if pkgs.stdenv.isLinux then "_github-runner" else null;
          extraPackages =
            with (if cfg.enableRosetta then pkgs.pkgsx86_64Darwin else pkgs);
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
              less
              ncurses
              netcat
              procps
              time
              zstd
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
          serviceOverrides = lib.optionalAttrs pkgs.stdenv.isLinux {
            # needed for Cachix installation to work
            ReadWritePaths = [ "/nix/var/nix/profiles/per-user/" ];

            # Allow writing to $HOME
            ProtectHome = "tmpfs";

            # Always restart, which is possible with a PAT.
            Restart = lib.mkForce "always";
            RestartSec = "30s";
          };
        }
        // lib.optionalAttrs cfg.enableRosetta {
          package = "/usr/bin/arch -x86_64 " + pkgs.pkgsx86_64Darwin.github-runner;
        }
        // lib.optionalAttrs pkgs.stdenv.isLinux { user = name i; }
        // cfg.extraService
      );
    })
    # The nix-darwin module already creates the user and group.
    (lib.mkIf pkgs.stdenv.isLinux {
      users.groups.${cfg.group} = { };

      users.users."_github-runner" = {
        group = cfg.group;
        extraGroups = cfg.extraGroups;

        # make sure we don't create home as the runner does
        isSystemUser = true;

        # Software like openssh executes getpwuid to get user's home.
        # because they won't want you to exploit setting $HOME.
        # On the other hand, systemd DynamicUser=1 sets it to /, which results into ...
        # a lot of confusion.
        # we set home entry in nss to match $HOME
        home = "/run/github-runner/github-runner";
      };
    })
  ]);
}

