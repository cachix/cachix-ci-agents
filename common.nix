{ pkgs, ... }:
{
environment.systemPackages = with pkgs; [ 
    vim 
    ncdu 
    git
    tmux 
    cachix
  ];

nix.extraOptions = ''
  min-free = ${toString (5 * 1024 * 1024 * 1024)}
  max-free = ${toString (20 * 1024 * 1024 * 1024)}
'';
}
