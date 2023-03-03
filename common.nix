{ pkgs, ... }:
{
environment.systemPackages = with pkgs; [ 
    vim 
    # zig broken on darwin
    #ncdu 
    git
    tmux 
    cachix
    direnv
  ];

nix.extraOptions = ''
  min-free = ${toString (5 * 1024 * 1024 * 1024)}
  max-free = ${toString (20 * 1024 * 1024 * 1024)}
'';
}
