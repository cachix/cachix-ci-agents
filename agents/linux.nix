{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/common.nix
    ../modules/github-runner.nix
  ];

  virtualisation.docker.enable = true;
  users.users.github-runner.extraGroups = [ "docker" ];

  sops.defaultSopsFile = ../secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  sops.secrets.github-runner-token.owner = "github-runner";

  cachix.github-runner = {
    enable = true;
    count = 8;
    githubOrganization = "cachix";
    namePrefix = "cachix-${pkgs.stdenv.system}";
    tokenFile = config.sops.secrets.github-runner-token.path;
  };

  system.stateVersion = "23.11";
}
