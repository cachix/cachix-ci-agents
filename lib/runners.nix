{ pkgs, lib, stdenv, ... }:
{ enable ? false,
  count ? 1,
  namePrefix ? "runner-${stdenv.system}",
  githubOrganization,
  tokenFile,
  extraPackages ? [ ],
  extraService ? { },
  serviceOverrides ? { },
  enableRosetta ? false,
  user ? null,
  group ? null,
  }:

let
  runners = lib.range 1 count;
  name = i: "${namePrefix}-${i}";
  mkRunners = f: builtins.listToAttrs (map (i: { name = name i; value = f i; }) runners);
in
mkRunners (i: lib.mkMerge [{
  inherit enable tokenFile user group;
  url = "https://github.com/${githubOrganization}";
  # Replace an existing runner with the same name, instead of erroring out.
  replace = true;
  # Re-launch the runner after each job.
  ephemeral = true;
  extraPackages =
    with (if enableRosetta then pkgs.pkgsx86_64Darwin else pkgs);
    [
      # custom
      cachix
      tmate
      jq
      git
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
      locale
      less
      ncurses
      netcat
      procps
      time
      zstd
      util-linux
      which
      nix
      nixos-rebuild
    ]
    ++ lib.optionals stdenv.isLinux [
      pkgs.strace
      pkgs.mkpasswd
      # nixos
      pkgs.acl
      pkgs.attr
      pkgs.libcap
    ]
    ++ lib.optionals stdenv.isDarwin [ ]
    ++ cfg.extraPackages;
  serviceOverrides = lib.mkMerge [
    (lib.optionalAttrs stdenv.isLinux {
      # needed for Cachix installation to work
      ReadWritePaths = [ "/nix/var/nix/profiles/per-user/" ];

      # Allow writing to $HOME
      ProtectHome = "tmpfs";

      # Always restart, which is possible with a PAT.
      Restart = lib.mkForce "always";
      RestartSec = "30s";
    })
    serviceOverrides
  ];
}
(lib.mkIf enableRosetta {
  package = "/usr/bin/arch -x86_64 " + pkgs.pkgsx86_64Darwin.github-runner;
})
(lib.mkIf pkgs.stdenv.isLinux { user = "_github-runner"; })
extraService
])

