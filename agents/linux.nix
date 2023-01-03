{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [ vim ncdu tmux ];

  system.stateVersion = "22.11";

  nix.settings.trusted-users = [ "root" "github-runner-cachix" ];

  systemd.services.github-runner-cachix.serviceConfig.ReadWritePaths = [ "/nix/var/nix/profiles/per-user/" ];

  services.github-runners.cachix = {
    enable = true;
    url = "https://github.com/cachix";
    tokenFile = "/etc/secrets/github-runner/cachix.token";
    extraPackages = [ pkgs.cachix ];
  };
}