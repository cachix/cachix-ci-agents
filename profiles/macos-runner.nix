# Reusable role for a macOS GitHub Actions runner, deployed as the
# "hetzner" user via cachix-deploy. Machine-specific tuning (hardware
# limits, hostname, ...) lives in the machine's own configuration.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./common.nix
    ./github-runner.nix
  ];

  nix.settings.trusted-users = [ "hetzner" ];

  services.cachix-agent.enable = true;
  services.openssh.enable = true;

  # Disable Touch ID and Watch ID pam integrations.
  # There's a permission error writing to /etc/pam.d.
  # Could be SIP related? We run our agent as root.
  security.pam.services.sudo_local.enable = false;

  cachix.github-runners = {
    runners."aarch64-darwin" = {
      enable = true;
      count = 2;
      githubOrganization = "cachix";
      namePrefix = "cachix-${pkgs.stdenv.system}-";
      tokenFile = config.age.secrets.github-runner-token.path;
      extraPackages = [ pkgs.devenv ];
    };

    runners."x86_64-darwin" = {
      enable = false;
      count = 2;
      rosetta.enable = true;
      githubOrganization = "cachix";
      namePrefix = "cachix-x86_64-darwin-rosetta-";
      tokenFile = config.age.secrets.github-runner-token.path;
      extraPackages = [ pkgs.devenv-x86 ];
    };
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
