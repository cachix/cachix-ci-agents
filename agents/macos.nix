{ pkgs, ... }:

{
  environment.systemPackages = [ 
    pkgs.vim
    pkgs.git
    pkgs.cachix
  ];

  nix.extraOptions = ''
    experimental-features = flakes nix-command
  '';
  nix.settings.trusted-users = ["root" "hetzner"];

  networking.hostName = "macos";
  services.cachix-agent.enable = true;

  # required on M1
  programs.zsh.enable = true;

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;
}