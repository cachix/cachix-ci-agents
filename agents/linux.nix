{ pkgs, ... }: {
  imports = [ ../common.nix ];

  # belong to cachix-deploy-flake
  boot.initrd.availableKernelModules = [ "md_mod" "raid1" ];

  system.stateVersion = "22.11";

  nix.settings.trusted-users = [ "root" "github-runner-cachix-linux" ];
  nix.extraOptions = ''
     extra-experimental-features = flakes nix-command
  '';

  systemd.services.github-runner-cachix-linux.serviceConfig.ReadWritePaths = [ "/nix/var/nix/profiles/per-user/" ];

  services.github-runners.cachix-linux = {
    enable = true;
    url = "https://github.com/cachix";
    tokenFile = "/etc/secrets/github-runner/cachix.token";
    extraPackages = [ pkgs.cachix ];
  };
}
