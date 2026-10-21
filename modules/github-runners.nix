{
  config,
  options,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cachix.github-runners;

  # Avoid infinite recursion with pkgs
  isLinux = options ? systemd;
  isDarwin = options ? launchd;

  # The limit that GitHub sets for a runner name.
  maxRunnerNameLength = 64;

  # Replace a setting of the upstream module.
  # The priority sits between a normal definition (100) and `lib.mkForce`
  # (50), so `serviceOverrides` can still force a different value.
  overrideUpstream = lib.mkOverride 90;

  enabledGroups = lib.filter (group: group.enable) (lib.attrValues cfg.runners);

  # One attribute set for each runner of each enabled group.
  runners = lib.concatMap (
    group:
    lib.genList (
      index:
      let
        number = index + 1;
      in
      {
        inherit group;
        # The name that GitHub shows.
        name = group.name number;
        # The `services.github-runners` attribute name.
        service = group.service number;
      }
    ) group.count
  ) enabledGroups;

  # The service unit that the upstream module creates.
  unitName = runner: "github-runner-${runner.service}";

  # Linux runs each runner as its own system user.
  # nix-darwin runs all runners as the `_github-runner` user that it creates.
  linuxUser = runner: runner.group.user runner.service;
  linuxHome = runner: runner.group.home runner.service;
  linuxWorkDir = runner: lib.mapNullable (workDir: workDir runner.service) runner.group.workDir;

  # systemd creates the work directory when it sits under /var/lib.
  linuxStateDirectories =
    runner:
    let
      workDir = linuxWorkDir runner;
    in
    lib.optional (workDir != null && lib.hasPrefix "/var/lib/" workDir) (
      lib.removePrefix "/var/lib/" workDir
    );

  # The tools that a workflow can expect on PATH.
  # `pkgs` is the x86_64-darwin package set for Rosetta runners.
  runnerPackages =
    pkgs: with pkgs; [
      # custom
      cachix
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

  # Settings for the systemd unit of one runner.
  # These merge with the upstream module and with `serviceOverrides` through
  # the systemd option types: lists are concatenated, other values conflict.
  linuxService = runner: {
    serviceConfig = {
      # Default workDir is under RuntimeDirectory, which is backed by tmpfs.
      # Use a separate StateDirectory for workDir to avoid self-referential
      # symlinks (NixOS/nixpkgs#289422).
      StateDirectory = linuxStateDirectories runner;

      # needed for Cachix installation to work
      ReadWritePaths = [ "/nix/var/nix/profiles/per-user/" ];

      # Allow writing to $HOME
      ProtectHome = "tmpfs";

      # Always restart, which is possible with a PAT.
      Restart = overrideUpstream "always";
      RestartSec = "30s";
    };
  };

  # Settings for the launchd daemon of one runner.
  darwinService = _runner: {
    serviceConfig = {
      # launchd cannot order jobs, so retry if the secret is not ready.
      KeepAlive = overrideUpstream true;

      # Don't run on load.
      # Wait for the secret provider to create the token and use that as a trigger.
      # The token is automatically added to WatchPaths.
      RunAtLoad = overrideUpstream false;
    };
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
        inherit (group) tokenFile serviceOverrides;
        url = "https://github.com/${group.githubOrganization}";
        # Replace an existing runner with the same name, instead of erroring out.
        replace = lib.mkDefault true;
        # Re-launch the runner after each job.
        ephemeral = lib.mkDefault true;
        extraPackages =
          runnerPackages (if group.rosetta.enable then pkgs.pkgsx86_64Darwin else pkgs)
          ++ lib.optionals isLinux linuxRunnerPackages
          ++ group.extraPackages;
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
      type = lib.types.attrsOf (lib.types.submodule ./github-runners/runner-group.nix);
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
        users."_github-runner".home = overrideUpstream "/private/var/lib/github-runners";
        groups.${cfg.group}.members = [ "_github-runner" ];
      })
    ];
  }
  // lib.optionalAttrs isLinux {
    systemd.services = forRunners unitName linuxService;
  }
  // lib.optionalAttrs isDarwin {
    launchd.daemons = forRunners unitName darwinService;
  };
}
