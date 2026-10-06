# A nix-darwin machine that runs GitHub Actions runners.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [ ./common.nix ];

  # nix-darwin's cachix-agent module has no verbose option; override its script
  # to pass the global --verbose flag while preserving credential loading.
  # TODO: Upstream services.cachix-agent.verbose to nix-darwin.
  launchd.daemons.cachix-agent.script = lib.mkForce ''
    . ${config.services.cachix-agent.credentialsFile}

    exec ${lib.getExe config.services.cachix-agent.package} --verbose deploy agent ${config.services.cachix-agent.name}
  '';

  # Disable Touch ID and Watch ID pam integrations.
  # There's a permission error writing to /etc/pam.d.
  # Could be SIP related? We run our agent as root.
  security.pam.services.sudo_local.enable = false;

  # x86_64-darwin runners through Rosetta. Switched off for now.
  cachix.github-runners.runners."x86_64-darwin" = {
    enable = false;
    count = config.cachix.machine.runners;
    rosetta.enable = true;
    githubOrganization = "cachix";
    namePrefix = "${config.networking.hostName}-x86_64-";
    servicePrefix = "x86_64-";
    tokenFile = config.age.secrets.github-runner-token.path;
    extraPackages = [ pkgs.devenv-x86 ];
  };

  # required on M1
  programs.zsh.enable = true;
  programs.zsh.interactiveShellInit = ''
    eval "$(direnv hook zsh)"
  '';

  # Spotlight indexing is useless on a headless CI machine and burns
  # CPU/disk churning through runner workdirs and nix store paths.
  system.activationScripts.postActivation.text = ''
    printf "disabling spotlight indexing... "
    mdutil -a -i off &> /dev/null || true
    mdutil -a -E &> /dev/null || true
    echo "ok"
  '';

  # Interrupted Nix builds can leave their temporary directories behind.
  # Nix keeps the top-level directory open for every live build, so only
  # remove old directories which have no open file descriptor. Build logs are
  # disabled in common.nix; clean up logs written before that setting changed.
  launchd.daemons.nix-clean-stale-state = {
    command = lib.getExe pkgs.nix-clean-stale-state;

    serviceConfig = {
      RunAtLoad = true;
      StartCalendarInterval = [
        {
          Hour = 4;
          Minute = 30;
        }
      ];
      ProcessType = "Background";
      LowPriorityIO = true;
      Nice = 15;
    };
  };

  # for some reason manual isn't reproducible so we disable it
  documentation.man.enable = lib.mkForce false;
  documentation.info.enable = lib.mkForce false;
  documentation.doc.enable = lib.mkForce false;

  system.stateVersion = 5;
}
