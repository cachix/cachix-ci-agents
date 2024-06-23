{ config, pkgs, lib, ... }:

let
  name = "cachix-${pkgs.stdenv.system}";
in {
  imports = [ ../common.nix ];

  nix.settings.trusted-users = [ "root" "github-runner" ];

  virtualisation.docker.enable = true;

  # create group github-runners
  users.groups.github-runner = {};

  users.users.github-runner.group = "github-runner";
  users.users.github-runner.extraGroups = [ "docker" ];
  users.users.github-runner.isNormalUser = true;
  # Software like openssh executes getpwuid to get user's home.
  # because they won't want you to exploit setting $HOME.
  # On the other hand, systemd DynamicUser=1 sets it to /, which results into ... 
  # a lot of confusion.
  # we set home entry in nss to match $HOME
  users.users.github-runner.home = "/run/github-runner/${name}";

  sops.defaultSopsFile = ../secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  sops.secrets.github-runner-token.owner = "github-runner";

  services.github-runners.${name} = {
    enable = true;
    url = "https://github.com/cachix";
    user = "github-runner";
    replace = true;
    tokenFile = config.sops.secrets.github-runner-token.path;
    serviceOverrides = {
      # needed for Cachix installation to work
      ReadWritePaths = [ "/nix/var/nix/profiles/per-user/" ];

      # Allow writing to $HOME
      ProtectHome = "tmpfs";

      # Always restart, which is possible with a PAT.
      Restart = lib.mkForce "always";
      RestartSec = "30s";
    };
    extraPackages = with pkgs; [ 
      # custom
        cachix 
        tmate
        jq
        # nixos
        docker
        openssh
        coreutils-full
        bashInteractive # bash with ncurses support
        bzip2
        cpio
        curl
        diffutils
        findutils
        gawk
        stdenv.cc.libc
        getent
        getconf
        gnugrep
        gnupatch
        gnused
        gnutar
        gzip
        xz
        less
        ncurses
        netcat
        mkpasswd
        procps
        time
        zstd
        util-linux
        which
        nixos-rebuild
    ];
  };

  system.stateVersion = "23.11";
}
