{ pkgs, ... }: 

let
  name = "cachix-${pkgs.stdenv.system}";
in {
  disabledModules = [ "services/continuous-integration/github-runners.nix" ];
  imports = [
    ../common.nix
    "${pkgs.unstable}/nixos/modules/services/continuous-integration/github-runners.nix"
  ];

  nix.settings.trusted-users = [ "root" "github-runner" ];
  nix.extraOptions = "extra-experimental-features = flakes nix-command";

  # create group github-runners
  users.groups.github-runner = {};

  users.users.github-runner.group = "github-runner";
  users.users.github-runner.isNormalUser = true;
  # Software like openssh executes getpwuid to get user's home.
  # because they won't want you to exploit setting $HOME.
  # On the other hand, systemd DynamicUser=1 sets it to /, which results into ... 
  # a lot of confusion.
  # we set home entry in nss to match $HOME
  users.users.github-runner.home = "/run/github-runner/${name}";

  services.github-runners.${name} = {
    enable = true;
    url = "https://github.com/cachix";
    user = "github-runner";
    tokenFile = "/etc/secrets/github-runner/cachix.token";
    nodeRuntimes = [ "node16" "node20" ];
    serviceOverrides = {
      # needed for Cachix installation to work
      ReadWritePaths = [ "/nix/var/nix/profiles/per-user/" ];

      # Allow writing to $HOME
      ProtectHome = "tmpfs";
    };
    extraPackages = with pkgs; [ 
      # custom
        cachix 
        tmate
        jq
        # nixos
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
}
