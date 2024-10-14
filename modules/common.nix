{ pkgs, ... }:

{
  nix.package = pkgs.nixVersions.nix_2_23;
  nix.settings.trusted-users = [ "root "];
  nix.extraOptions = ''
    always-allow-substitutes = true
    min-free = ${toString (10 * 1024 * 1024 * 1024)}
    max-free = ${toString (30 * 1024 * 1024 * 1024)}
    extra-experimental-features = flakes nix-command
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

  sops.defaultSopsFile = ../secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  sops.secrets.github-runner-token.group = "github-runner";
}
