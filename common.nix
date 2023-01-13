{ pkgs, ... }:
{
environment.systemPackages = with pkgs; [ 
    vim 
    ncdu 
    git
    tmux 
    cachix
  ];
}
