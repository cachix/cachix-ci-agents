{ pkgs, ... }:

{
  nix.package = pkgs.nixVersions.nix_2_23;
  nix.settings.cores = 4;
  nix.extraOptions = ''
    min-free = ${toString (5 * 1024 * 1024 * 1024)}
    max-free = ${toString (20 * 1024 * 1024 * 1024)}
  '';
  environment.systemPackages = with pkgs; [ 
    vim 
    # zig broken on darwin
    #ncdu 
    git
    tmux 
    cachix
    direnv
  ];

}
