{
  pkgs,
  lib,
  config,
  ...
}:

let
  anyRunnerEnabled = (lib.any (cfg: cfg.enable) (lib.attrValues config.cachix.github-runners.runners));
in
{
  options.cachix.github-runners = {
    group = lib.mkOption {
      type = lib.types.str;
      default = "_github-runner";
      description = "The group to create and run the runner as";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra groups to add to each runner user";
    };

    runners = lib.mkOption {
      description = "Customized GitHub runners";
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        enable = lib.mkEnableOption "GitHub runners.";

        name = lib.mkOption {
          type = lib.types.str;
          description = "The name to use for the runner";
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
          description = "The group to create and run the runner as";
          default = config.cachix.github-runners.group;
        };

        enableRosetta = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable rosetta on Apple Silicon";
        };

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

      }));
    };
  };

  # create each github runner
  # NOTE: see https://github.com/NixOS/nixpkgs/issues/231427#issuecomment-1545312478 how to prevent inf rec
  config.services.github-runners = lib.flip lib.mapAttrs' config.cachix.github-runners (name: cfg:
      lib.nameValuePair name (lib.mkIf cfg.enable {
        services.github-runners.${name} = lib.mkMerge [{
          enable = cfg.enable;
          url = "https://github.com/${cfg.githubOrganization}";
          tokenFile = cfg.tokenFile;
          # Replace an existing runner with the same name, instead of erroring out.
          replace = true;
          # Re-launch the runner after each job.
          ephemeral = true;
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
              locale
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
        (lib.mkIf cfg.enableRosetta {
          package = "/usr/bin/arch -x86_64 " + pkgs.pkgsx86_64Darwin.github-runner;
        })
        (lib.mkIf pkgs.stdenv.isLinux { user = "_github-runner"; })
        cfg.extraService
      ];
    })
  );

  config.nix.settings = lib.mkIf anyRunnerEnabled {
    trusted-users = [ "_github-runner" ];
  };

  config.users = lib.mkIf (lib.any (cfg: cfg.enable) (lib.attrValues config.cachix.github-runners.runners)) (lib.mkMerge [
    # The nix-darwin module already creates the user and group.
    (lib.mkIf (pkgs.stdenv.isLinux) {
      groups.${config.cachix.github-runners.group} = { };

      users."_github-runner" = {
        group = config.cachix.github-runners.group;
        extraGroups = config.cachix.github-runners.extraGroups;

        # make sure we don't create home as the runner does
        isSystemUser = true;

        # Software like openssh executes getpwuid to get user's home.
        # because they won't want you to exploit setting $HOME.
        # On the other hand, systemd DynamicUser=1 sets it to /, which results into ...
        # a lot of confusion.
        # we set home entry in nss to match $HOME
        home = "/run/github-runner/github-runner";

        # Allow interactive shells (e.g. nix shell)
        useDefaultShell = true;
      };
    })
  ]);
}
