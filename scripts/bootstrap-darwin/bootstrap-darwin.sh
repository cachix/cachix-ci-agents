#!/usr/bin/env bash
# Bootstrap a Cachix Deploy agent on a Mac over SSH.
#
# This is the nix-darwin counterpart of bootstrap-hetzner.
set -euo pipefail

prog=$(basename "$0")

usage() {
  cat <<EOF
Usage: $prog [options] <ssh-destination> <agent-name> <cachix-agent-token-path>

Install Nix on a Mac, copy the Cachix Deploy agent token to
/etc/cachix-agent.token, and activate <flake>#darwinConfigurations.<agent-name>.

The SSH user must be an admin who can run sudo. The token file must contain
the line below, with or without "export":

  CACHIX_AGENT_TOKEN=...

Options:
  --flake <ref>                Flake with the configuration (default: .)
  --rosetta                    Install Rosetta 2 on Apple Silicon
  --build-on-remote            Build the configuration on the Mac
  --nix-installer-url <url>    Nix installer (default: $nix_installer_url)
  -o, --ssh-option <option>    Extra ssh option, for example Port=2222
  -h, --help                   Show this help

Example:
  $prog admin@192.0.2.10 myagent ./myagent.token
EOF
}

log() {
  printf '\033[1;34m==>\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
  exit 1
}

flake=.
rosetta=
build_on_remote=
nix_installer_url=https://nixos.org/nix/install
extra_ssh_opts=()
positional=()

while [ "$#" -gt 0 ]; do
  case "$1" in
  --flake)
    flake=${2:?--flake needs a value}
    shift 2
    ;;
  --rosetta)
    rosetta=1
    shift
    ;;
  --build-on-remote)
    build_on_remote=1
    shift
    ;;
  --nix-installer-url)
    nix_installer_url=${2:?--nix-installer-url needs a value}
    shift 2
    ;;
  -o | --ssh-option)
    extra_ssh_opts+=(-o "${2:?$1 needs a value}")
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  --)
    shift
    positional+=("$@")
    break
    ;;
  -*)
    usage >&2
    die "unknown option: $1"
    ;;
  *)
    positional+=("$1")
    shift
    ;;
  esac
done

if [ "${#positional[@]}" -ne 3 ]; then
  usage >&2
  exit 1
fi

dest=${positional[0]}
agent=${positional[1]}
token_path=${positional[2]}

[ -r "$token_path" ] || die "cannot read the agent token: $token_path"
grep -q 'CACHIX_AGENT_TOKEN=' "$token_path" ||
  die "$token_path must contain CACHIX_AGENT_TOKEN=..."

# The part that runs on the Mac. It is next to this script.
remote_script=$(dirname "$(readlink -f "$0")")/remote.sh
[ -r "$remote_script" ] || die "cannot find the remote script: $remote_script"

nix_cmd=(nix --extra-experimental-features "nix-command flakes")

# Keep the path short: it holds the SSH control socket, and Unix socket paths
# are limited to 104 bytes on macOS.
local_tmp=$(mktemp -d /tmp/bootstrap-darwin.XXXXXX)
remote_tmp=

# Share one SSH connection between all steps, including `nix copy`, so that
# the user authenticates only once.
ssh_opts=(
  -o ControlMaster=auto
  -o "ControlPath=$local_tmp/%C"
  -o ControlPersist=120
  "${extra_ssh_opts[@]}"
)
NIX_SSHOPTS="${ssh_opts[*]}"
export NIX_SSHOPTS

# Callers pass one command string for the remote shell. They quote
# arguments with `printf %q`.
# shellcheck disable=SC2029
remote() {
  ssh "${ssh_opts[@]}" "$dest" "$@"
}

# Allocate a terminal when we have one, so that sudo can ask for a password.
# shellcheck disable=SC2029
remote_tty() {
  if [ -t 0 ]; then
    ssh -t "${ssh_opts[@]}" "$dest" "$@"
  else
    ssh "${ssh_opts[@]}" "$dest" "$@"
  fi
}

# Run a remote.sh command.
#
# TODO: Do not trust the exit status of ssh: Tailscale SSH reports 0 for every command.
# The command writes its status to a file instead, and we read that file.
remote_step() {
  local status_file=$remote_tmp/status status
  remote_tty "rm -f $(printf %q "$status_file"); bash $(printf '%q ' "$remote_tmp/remote.sh" "$@"); echo \$? > $(printf %q "$status_file")"
  status=$(remote "cat $(printf %q "$status_file")")
  [ "$status" = 0 ] || die "$1 failed on $dest (status ${status:-unknown})"
}

cleanup() {
  if [ -n "$remote_tmp" ]; then
    remote "rm -rf $(printf %q "$remote_tmp")" || true
  fi
  ssh "${ssh_opts[@]}" -O exit "$dest" 2>/dev/null || true
  rm -rf "$local_tmp"
}
trap cleanup EXIT

installable="$flake#darwinConfigurations.\"$agent\".system"

log "Evaluating $installable ..."
config_system=$("${nix_cmd[@]}" eval --raw "$installable.system") ||
  die "cannot evaluate darwinConfigurations.$agent in $flake"

log "Connecting to $dest ..."
[ "$(remote uname -s)" = Darwin ] || die "$dest is not running macOS"
case "$(remote uname -m)" in
arm64) remote_system=aarch64-darwin ;;
x86_64) remote_system=x86_64-darwin ;;
*) die "unsupported architecture on $dest" ;;
esac
[ "$config_system" = "$remote_system" ] ||
  die "darwinConfigurations.$agent is for $config_system, but $dest is $remote_system"
remote_user=$(remote id -un)

remote_tmp=$(remote mktemp -d /tmp/bootstrap-darwin.XXXXXX)
[ -n "$remote_tmp" ] || die "cannot create a temporary directory on $dest"
remote "cat > $(printf %q "$remote_tmp/remote.sh")" <"$remote_script"
remote "umask 077 && cat > $(printf %q "$remote_tmp/agent.token")" <"$token_path"

prepare_args=(
  prepare
  --nix-installer-url "$nix_installer_url"
  --token "$remote_tmp/agent.token"
  --trusted-user "$remote_user"
)
if [ -n "$rosetta" ]; then
  prepare_args+=(--rosetta)
fi
remote_step "${prepare_args[@]}"

nix_bin=$(remote "bash $(printf %q "$remote_tmp/remote.sh") nix-bin")
[ -n "$nix_bin" ] || die "cannot find Nix on $dest"
store="ssh-ng://$dest?remote-program=$nix_bin/nix-daemon"

if [ -n "$build_on_remote" ]; then
  log "Building $installable on $dest ..."
  system_config=$("${nix_cmd[@]}" build --no-link --print-out-paths \
    --eval-store auto --store "$store" "$installable")
else
  log "Building $installable ..."
  system_config=$("${nix_cmd[@]}" build --no-link --print-out-paths "$installable")
  log "Copying $system_config to $dest ..."
  # Locally built paths have no signature. The daemon accepts them only
  # with --no-check-sigs and only from a trusted user.
  "${nix_cmd[@]}" copy --no-check-sigs --substitute-on-destination \
    --to "$store" "$system_config"
fi

remote_step activate "$system_config"

log "Done. Agent $agent should now connect to Cachix Deploy."
log "Agent logs: ssh $dest tail -f /var/log/cachix-agent.log"
