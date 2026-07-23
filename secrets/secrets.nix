let
  sshKeys = import ../ssh-keys.nix;

  admins = builtins.attrValues sshKeys.admins;
  servers = builtins.attrValues sshKeys.hosts;
in
{
  # PAT for runner registration
  # https://github.com/settings/personal-access-tokens/new
  #
  # Resource owner: cachix
  # Organization permissions: Self-hosted runners (read and write)
  # Expires: 23/12/2026
  "github-runner-token.age".publicKeys = admins ++ servers;

  # extra-access-tokens for Nix.
  # Use a classic token to work around NixOS fine-grained expiriration policy (90 days).
  # Includes:
  #   - github.com basic token. @sandydoo Expires: 15/05/2027
  "nix-access-tokens.age".publicKeys = admins ++ servers;
}
