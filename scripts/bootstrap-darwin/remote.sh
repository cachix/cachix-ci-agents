#!/bin/bash
# The part of bootstrap-darwin that runs on the Mac, as the SSH user.
#
# Keep this compatible with the bash 3.2 that ships with macOS: no
# associative arrays, no mapfile, and no empty arrays under `set -u`.
set -euo pipefail

log() {
  printf '\033[1;34m==>\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
  exit 1
}

# Print the directory with the Nix binaries. Prefer the nix-darwin system,
# because the installer's default profile can be older or missing.
nix_bin() {
  for dir in /run/current-system/sw/bin /nix/var/nix/profiles/default/bin; do
    if [ -x "$dir/nix-daemon" ]; then
      echo "$dir"
      return
    fi
  done
  return 1
}

wait_for_daemon() {
  local bin
  bin=$(nix_bin)
  for _ in $(seq 30); do
    # The parent of the bin directory is a store path in both profiles.
    if "$bin/nix-store" --store daemon --query --hash "${bin%/bin}" >/dev/null 2>&1; then
      return
    fi
    sleep 1
  done
  die "the Nix daemon did not start"
}

prepare() {
  local rosetta='' installer_url='' token='' trusted_user=''
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --rosetta)
        rosetta=1
        shift
        ;;
      --nix-installer-url)
        installer_url=$2
        shift 2
        ;;
      --token)
        token=$2
        shift 2
        ;;
      --trusted-user)
        trusted_user=$2
        shift 2
        ;;
      *) die "prepare: unknown argument: $1" ;;
    esac
  done

  # Ask for the password once. sudo caches it for this session. Do not use
  # `sudo -v`: it asks for a password even with a NOPASSWD rule when another
  # rule, such as the default one for %admin, needs a password.
  sudo true

  if [ -n "$rosetta" ] && [ "$(uname -m)" = arm64 ]; then
    if /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
      log "Rosetta is already installed"
    else
      log "Installing Rosetta ..."
      sudo softwareupdate --install-rosetta --agree-to-license
    fi
  fi

  if nix_bin >/dev/null; then
    log "Nix is already installed"
  else
    log "Installing Nix from $installer_url ..."
    local installer
    installer=$(mktemp)
    curl --proto '=https' --tlsv1.2 -fsSL "$installer_url" -o "$installer"
    # The installer must run as a normal user. It calls sudo itself.
    sh "$installer" --daemon --yes </dev/null
    rm -f "$installer"
  fi

  # `nix copy` sends unsigned store paths. The daemon accepts these only from
  # trusted users. The nix-darwin configuration replaces this file later.
  local conf=/etc/nix/nix.conf
  if [ -L "$conf" ]; then
    log "$conf is managed by nix-darwin, not changing trusted-users"
  elif grep -qx "extra-trusted-users = $trusted_user" "$conf" 2>/dev/null; then
    log "$trusted_user is already a trusted Nix user"
  else
    log "Adding $trusted_user to the trusted Nix users ..."
    printf '\nextra-trusted-users = %s\n' "$trusted_user" | sudo tee -a "$conf" >/dev/null
    sudo launchctl kickstart -k system/org.nixos.nix-daemon
  fi
  wait_for_daemon

  # The nix-darwin service sources this file in a shell, so the variable must
  # be exported. Also accept the NixOS EnvironmentFile format without export.
  log "Installing the agent token to /etc/cachix-agent.token ..."
  sed -E 's/^[[:space:]]*(export[[:space:]]+)?CACHIX_AGENT_TOKEN=/export CACHIX_AGENT_TOKEN=/' \
    "$token" >"$token.export"
  sudo install -m 600 -o root -g wheel "$token.export" /etc/cachix-agent.token
}

activate() {
  local system_config=$1 bin profile=/nix/var/nix/profiles/system-profiles/system
  [ -x "$system_config/activate" ] || die "$system_config is not a nix-darwin system"
  [ -x "$system_config/sw/bin/darwin-rebuild" ] ||
    die "$system_config has no darwin-rebuild, which the agent needs to deploy"
  bin=$(nix_bin)

  sudo true

  # nix-darwin refuses to replace unknown files in /etc that it manages,
  # such as the nix.conf and shell rc files from the Nix installer. Move them
  # aside the same way nix-darwin asks users to.
  local link sub target
  find -H "$system_config/etc" -type l -print0 | while IFS= read -r -d '' link; do
    sub=${link#"$system_config"/etc/}
    target=/etc/$sub
    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
      continue
    fi
    if [ "$(readlink "$target")" = "/etc/static/$sub" ]; then
      continue
    fi
    if [ -e "$target.before-nix-darwin" ]; then
      die "$target.before-nix-darwin already exists, move $target aside by hand"
    fi
    log "Moving $target to $target.before-nix-darwin"
    sudo mv "$target" "$target.before-nix-darwin"
  done

  # Use the same profile and activation command as the Cachix Deploy agent,
  # so that later deployments continue this profile.
  log "Activating $system_config ..."
  sudo mkdir -p -m 0755 "$(dirname "$profile")"
  sudo -H "$bin/nix-env" -p "$profile" --set "$system_config"
  sudo -H "$system_config/sw/bin/darwin-rebuild" activate

  if sudo launchctl print system/org.nixos.cachix-agent >/dev/null 2>&1; then
    log "The cachix-agent service is loaded"
  else
    log "warning: the cachix-agent service is not loaded." \
      "Check that the configuration enables services.cachix-agent."
  fi
}

cmd=${1:-}
[ "$#" -gt 0 ] && shift
case "$cmd" in
  prepare) prepare "$@" ;;
  activate) activate "$@" ;;
  nix-bin) nix_bin ;;
  *) die "usage: $0 {prepare|activate|nix-bin} ..." ;;
esac
